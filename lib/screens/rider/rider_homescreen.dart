// Updated RiderHomeScreen.dart with custom MP3 sound alerts
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart'; // For playing custom MP3 sounds
import 'package:riderhub/screens/delivery_tracking_screen.dart';
import 'package:riderhub/screens/login.dart';
import 'package:riderhub/screens/rider/current_job_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:riderhub/screens/rider/help_support_screen.dart';
import 'package:riderhub/screens/rider/history_screen.dart';
import 'package:riderhub/screens/rider/notifications_screen.dart';
import 'package:riderhub/screens/rider/profile_screen.dart';
import 'package:riderhub/screens/rider/wallet_screen.dart';
import 'package:riderhub/screens/rider/job_list_screen.dart';

import 'dart:async';
import 'dart:math' as Math;

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  StreamSubscription<Position>? _positionStreamSubscription;
  int? _currentDeliveryId;
  int _selectedIndex = 0;
  int _bottomNavIndex = 0;
  bool _isOnline = false;
  String _currentStatus = 'Offline';

  // User profile
  String _userName = 'Rider';
  String _userPhone = '';
  String _userType = 'rider';
  String? _profileImage;
  bool _isLoading = true;

  // Map
  GoogleMapController? mapController;
  LatLng? currentLatLng;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  // Jobs
  List<Map<String, dynamic>> nearbyJobs = [];
  Set<int> _previousJobIds = {}; // Track previous job IDs for comparison
  Timer? _jobPollingTimer;

  // Current job tracking
  Map<String, dynamic>? _currentJob;
  String _jobStatus = 'None';

  // Audio player for custom MP3 sounds
  AudioPlayer? _audioPlayer;
  bool _soundEnabled = true;
  bool _isSoundLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _loadUserProfile();
    _getCurrentLocation();
    _initializeAudioPlayer();
  }

  @override
  void dispose() {
    _jobPollingTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _audioPlayer?.dispose();
    mapController?.dispose();
    super.dispose();
  }

  // Initialize audio player and load custom MP3 sound
  Future<void> _initializeAudioPlayer() async {
    _audioPlayer = AudioPlayer();

    try {
      // Set audio player configuration
      await _audioPlayer?.setVolume(1.0); // 80% volume
      await _audioPlayer?.setReleaseMode(ReleaseMode.stop); // Stop when done

      // IMPORTANT: Load your custom MP3 sound from assets
      // Make sure to add the sound file to your pubspec.yaml
      // Example: assets/sounds/job_notification.mp3

      // You can use different loading methods:
      // Method 1: From assets (recommended for mobile apps)
      // await _audioPlayer?.setSource(AssetSource('sounds/job_notification.mp3'));

      // Method 2: From network URL (for web or if sound is hosted online)
      // await _audioPlayer?.setSource(UrlSource('https://yourdomain.com/sounds/job_notification.mp3'));

      // Method 3: From app's local filesystem (for downloaded sounds)
      // await _audioPlayer?.setSource(DeviceFileSource('/path/to/sound.mp3'));

      // For now, let's use assets. Uncomment and modify the path to your actual sound file:
      // await _audioPlayer?.setSource(AssetSource('sounds/notification.mp3'));

      // Or use this simpler approach:
      // Load the sound when needed instead of pre-loading
      _isSoundLoaded = true;
    } catch (e) {
      debugPrint('Audio initialization error: $e');
      _isSoundLoaded = false;
    }
  }

  // Load user sound preferences
  Future<void> _loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
  }

  // Play custom MP3 notification sound
  Future<void> _playCustomNotificationSound(int newJobsCount) async {
    if (!_soundEnabled) return;

    try {
      // Play the custom MP3 sound
      await _playCustomMP3Sound();

      // Add haptic feedback for better user experience
      if (newJobsCount >= 3) {
        HapticFeedback.heavyImpact();
      } else if (newJobsCount == 2) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Custom sound play error: $e');
      // Fallback to system sound and vibration
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
    }
  }

  // Play your custom MP3 sound
  Future<void> _playCustomMP3Sound() async {
    try {
      // Method 1: Play from assets (recommended)
      // Make sure to add your sound file to pubspec.yaml
      // assets:
      //   - assets/sounds/notification.mp3
      /*
      await _audioPlayer?.play(AssetSource('sounds/notification.mp3'));
      */

      // Method 2: Play from network URL
      // Uncomment and replace with your actual sound URL
      /*
      await _audioPlayer?.play(UrlSource('https://chareta.com/riderhub/sounds/notification.mp3'));
      */

      // Method 3: Simple system sound (fallback)
      SystemSound.play(SystemSoundType.click);

      // Method 4: Using a different approach with cache
      // This is useful if you want to ensure the sound plays reliably
      if (!_isSoundLoaded) {
        // Try to load the sound
        try {
          // Load from assets
          // await _audioPlayer?.setSource(AssetSource('sounds/notification.mp3'));
          _isSoundLoaded = true;
        } catch (e) {
          debugPrint('Failed to load sound: $e');
        }
      }

      if (_isSoundLoaded) {
        // If loaded, play it
        await _audioPlayer?.resume(); // Or use play() if you've set the source
      } else {
        // Fallback
        SystemSound.play(SystemSoundType.click);
      }
    } catch (e) {
      debugPrint('MP3 sound play error: $e');
      // Ultimate fallback
      SystemSound.play(SystemSoundType.click);
    }
  }

  // Test the custom sound
  Future<void> _testCustomSound() async {
    if (!_soundEnabled) {
      // Enable sound first
      setState(() => _soundEnabled = true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sound_enabled', true);
    }

    await _playCustomMP3Sound();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔊 Testing custom sound...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // Check for new jobs and trigger sound alerts
  void _checkForNewJobs(List<Map<String, dynamic>> newJobs) {
    if (!_isOnline || !_soundEnabled) return;

    final Set<int> currentJobIds = Set.from(
      newJobs.map((job) => job['id'] as int),
    );
    final Set<int> newJobIds = currentJobIds.difference(_previousJobIds);

    if (newJobIds.isNotEmpty) {
      final int newJobsCount = newJobIds.length;

      // Play custom MP3 sound notification
      _playCustomNotificationSound(newJobsCount);

      // Show in-app snackbar (visual feedback only)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$newJobsCount new job${newJobsCount > 1 ? 's' : ''} available!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    // Update previous job IDs
    _previousJobIds = currentJobIds;
  }

  // Load user profile from API
  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://chareta.com/riderhub/api/api.php?action=profile',
            ),
            headers: {'X-Session-Id': sessionId},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] == null) {
          setState(() {
            _userName = data['name'] ?? 'Rider';
            _userPhone = data['phone'] ?? '';
            _userType = data['user_type'] ?? 'rider';
            _profileImage = data['face_picture'];
            _isLoading = false;
          });

          prefs.setString('user_name', _userName);
          prefs.setString('user_phone', _userPhone);
          prefs.setString('user_type', _userType);
        }
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
      setState(() => _isLoading = false);
    }
  }

  // Toggle online/offline
  void _toggleOnlineStatus() {
    setState(() {
      _isOnline = !_isOnline;
      _currentStatus = _isOnline ? 'Online - Available' : 'Offline';
    });

    if (_isOnline) {
      _startFetchingNearbyJobs();
      if (_currentDeliveryId != null) {
        _resumeBackgroundLocationUpdates();
      }
    } else {
      _jobPollingTimer?.cancel();
      _stopBackgroundLocationUpdates();
      setState(() {
        markers.removeWhere((m) => m.markerId.value.startsWith('job_'));
        nearbyJobs.clear();
        _previousJobIds.clear();
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isOnline ? 'You are now ONLINE' : 'You are now OFFLINE'),
        backgroundColor: _isOnline ? Colors.green : Colors.grey,
      ),
    );
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      currentLatLng = LatLng(position.latitude, position.longitude);

      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLatLng!,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentLatLng!, 14),
      );

      if (_isOnline) _fetchNearbyJobs();

      setState(() {});
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  void _startBackgroundLocationUpdates(int deliveryId) async {
    _currentDeliveryId = deliveryId;
    debugPrint(
      'Starting background location updates for delivery: $deliveryId',
    );

    final permission = await Geolocator.requestPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      debugPrint('Location permission denied: $permission');
      return;
    }

    _positionStreamSubscription?.cancel();

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 20,
            timeLimit: const Duration(seconds: 30),
          ),
        ).listen(
          (Position position) async {
            debugPrint(
              'Background location update: ${position.latitude}, ${position.longitude}',
            );
            await _updateLocationToServer(deliveryId, position);
          },
          onError: (error) {
            debugPrint('Location stream error: $error');
          },
        );
  }

  Future<void> _updateLocationToServer(
    int deliveryId,
    Position position,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) {
      debugPrint('No session ID for location update');
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(
              'https://chareta.com/riderhub/api/api.php?action=update_delivery_location',
            ),
            headers: {
              'X-Session-Id': sessionId,
              'Content-Type': 'application/json',
            },

            body: jsonEncode({
              'delivery_id': deliveryId,
              'lat': position.latitude,
              'lng': position.longitude,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('Location updated successfully');
      } else {
        debugPrint('Location update failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Background location update error: $e');
    }
  }

  void _stopBackgroundLocationUpdates() {
    debugPrint('Stopping background location updates');
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _currentDeliveryId = null;
  }

  void _resumeBackgroundLocationUpdates() {
    if (_currentDeliveryId != null && _isOnline) {
      debugPrint(
        'Resuming background location updates for delivery: $_currentDeliveryId',
      );
      _startBackgroundLocationUpdates(_currentDeliveryId!);
    }
  }

  // Start polling for nearby jobs with sound alerts
  void _startFetchingNearbyJobs() {
    _fetchNearbyJobs();
    _jobPollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isOnline && mounted) _fetchNearbyJobs();
    });
  }

  // Fetch real jobs from delivery_orders table with sound alerts
  Future<void> _fetchNearbyJobs() async {
    if (currentLatLng == null || !_isOnline) return;

    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) return;

    try {
      final url = Uri.parse(
        'https://chareta.com/riderhub/api/api.php?action=requests_nearby'
        '&lat=${currentLatLng!.latitude}'
        '&lng=${currentLatLng!.longitude}'
        '&radius=50',
      );

      final response = await http.get(
        url,
        headers: {'X-Session-Id': sessionId},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['error'] == null && json['requests'] is List) {
          final List jobs = json['requests'];

          // Remove old job markers
          markers.removeWhere((m) => m.markerId.value.startsWith('job_'));

          List<Map<String, dynamic>> newJobs = [];

          for (var job in jobs) {
            final lat = job['pickup_lat'] as double?;
            final lng = job['pickup_lng'] as double?;
            if (lat == null || lng == null) continue;

            final jobId = job['id'].toString();

            markers.add(
              Marker(
                markerId: MarkerId('job_$jobId'),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: job['parcel_size'] ?? 'Parcel',
                  snippet:
                      "Fare: \$${job['suggested_fare']?.toStringAsFixed(2) ?? '?.??'} • ${(job['distance'] as num?)?.toStringAsFixed(1) ?? '?'} km",
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
                onTap: () => _showJobDetails(Map<String, dynamic>.from(job)),
              ),
            );

            newJobs.add(Map<String, dynamic>.from(job));
          }

          if (mounted) {
            setState(() {
              nearbyJobs = newJobs;
            });
          }

          // Check for new jobs and trigger sound alerts
          _checkForNewJobs(newJobs);
        }
      }
    } catch (e) {
      debugPrint('Fetch nearby jobs error: $e');
    }
  }

  // Show job details bottom sheet
  void _showJobDetails(Map<String, dynamic> job) {
    final suggestedFare = (job['suggested_fare'] as num?)?.toDouble() ?? 0.0;
    final distance = (job['distance'] as num?)?.toDouble() ?? 0.0;

    // Extract new fields (with fallback)
    final pickupAddress = job['pickup_address'] as String? ?? 'Not provided';
    final dropoffNote =
        job['dropoff_note'] as String? ?? 'No special instructions';

    var distanceInMeters = 0;
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
            // Drag handle
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
            const SizedBox(height: 16),

            // Title
            Text(
              job['parcel_size'] ?? 'Delivery Job',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Fare & Distance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Offer: \$${suggestedFare.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "eligible",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Payment: ${job['payment_method']?.toString().toUpperCase() ?? 'Not specified'}',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
            ),

            const SizedBox(height: 16),

            // Pickup Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup Address',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pickupAddress,
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Dropoff Note / Instructions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note_alt, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dropoff Instructions',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(dropoffNote, style: GoogleFonts.inter(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),

            // Parcel Photo (if exists)
            if (job['parcel_photo'] != null) ...[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  'https://chareta.com/riderhub/api/${job['parcel_photo']}',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, size: 50),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _acceptJob(job, suggestedFare);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Accept \$${suggestedFare.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showBidDialog(job);
                    },
                    child: const Text('Bid Fare'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showBidDialog(Map<String, dynamic> job) {
    final controller = TextEditingController(
      text: (job['suggested_fare'] as num?)?.toStringAsFixed(2),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bid Your Fare'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount (USD)',
            prefixText: '\$ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final bid = double.tryParse(controller.text) ?? 0.0;
              if (bid > 0) {
                Navigator.pop(ctx);
                _submitBid(job, bid);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid bid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Submit Bid'),
          ),
        ],
      ),
    );
  }

  // Submit bid
  Future<void> _submitBid(Map<String, dynamic> job, double bidAmount) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null) return;

    try {
      final response = await http.post(
        Uri.parse('https://chareta.com/riderhub/api/api.php?action=submit_bid'),
        headers: {
          'X-Session-Id': sessionId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'delivery_order_id': job['id'],
          'bid_amount': bidAmount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bid submitted: \$${bidAmount.toStringAsFixed(2)}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Failed to submit bid'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit bid'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Submit bid error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Accept job
  Future<void> _acceptJob(Map<String, dynamic> job, double fare) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Not logged in. Please restart app.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Accepting job...'),
          ],
        ),
      ),
    );

    try {
      debugPrint('=== ACCEPT JOB REQUEST ===');
      debugPrint('Job ID: ${job['id']}');
      debugPrint('Session ID: $sessionId');
      debugPrint('Fare: $fare');

      final response = await http
          .post(
            Uri.parse(
              'https://chareta.com/riderhub/api/api.php?action=accept_job',
            ),
            headers: {
              'X-Session-Id': sessionId,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'delivery_order_id': job['id'], 'fare': fare}),
          )
          .timeout(const Duration(seconds: 30));

      Navigator.pop(context); // Close loading dialog

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          // Remove the accepted job from the map
          setState(() {
            markers.removeWhere((m) => m.markerId.value == 'job_${job['id']}');
            nearbyJobs.removeWhere((j) => j['id'] == job['id']);
            _previousJobIds.remove(job['id']);
          });

          // Set current job
          setState(() {
            _currentJob = job;
            _jobStatus = 'On Delivery';
            _currentJob?['delivery_id'] = data['delivery_id'];
            _currentJob?['assignment_id'] = data['delivery_id'];
          });

          // Start tracking location updates
          _startBackgroundLocationUpdates(data['delivery_id']);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✅ Job Accepted Successfully!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Delivery ID: ${data['delivery_id']}'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Navigate to delivery tracking screen
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeliveryTrackingScreen(
                assignmentId: data['delivery_id'],
                jobDetails: job,
              ),
            ),
          );
        } else {
          final errorMessage = data['error'] ?? 'Unknown server error';
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('❌ Job Acceptance Failed'),
              content: Text(
                'Server Error: $errorMessage\n\n'
                'Job ID: ${job['id']}\n'
                'Fare: \$$fare\n'
                'Status: ${job['status'] ?? 'unknown'}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else if (response.statusCode == 400) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invalid Request'),
            content: Text(
              'Status: ${response.statusCode}\n\n'
              'The server couldn\'t understand your request.\n'
              'Please check if the job still exists.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please log in again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        _logout();
      } else if (response.statusCode == 403) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Access Denied'),
            content: const Text(
              'You need to be a verified rider to accept jobs.\n\n'
              'Please complete your rider application first.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Job #${job['id']} no longer exists or was taken by another rider.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        _fetchNearbyJobs();
      } else if (response.statusCode == 409) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Job Already Taken'),
            content: const Text(
              'This job was accepted by another rider.\n\n'
              'Please select another job.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _fetchNearbyJobs();
                },
                child: const Text('Refresh Jobs'),
              ),
            ],
          ),
        );

        setState(() {
          markers.removeWhere((m) => m.markerId.value == 'job_${job['id']}');
          nearbyJobs.removeWhere((j) => j['id'] == job['id']);
          _previousJobIds.remove(job['id']);
        });
      } else if (response.statusCode == 500) {
        try {
          final errorData = jsonDecode(response.body);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Server Error'),
              content: Text(
                'Status: ${response.statusCode}\n\n'
                'Error: ${errorData['error'] ?? 'Internal server error'}\n\n'
                'Please try again in a moment.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } catch (e) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Server Error'),
              content: Text(
                'Status: ${response.statusCode}\n\n'
                'The server encountered an error.\n'
                'Please try again later.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unexpected Response'),
            content: Text(
              'Status: ${response.statusCode}\n\n'
              'Response: ${response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on TimeoutException {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request Timeout'),
          content: const Text(
            'The request took too long to complete.\n\n'
            'Please check your internet connection and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on http.ClientException catch (e) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Network Error'),
          content: Text(
            'Failed to connect to server.\n\n'
            'Error: ${e.message}\n\n'
            'Please check your internet connection.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on FormatException catch (e) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Response'),
          content: Text(
            'Server returned invalid data.\n\n'
            'Error: ${e.message}\n\n'
            'Please contact support if this continues.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      Navigator.pop(context);
      debugPrint('=== UNEXPECTED ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unexpected Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('An unexpected error occurred:'),
              const SizedBox(height: 8),
              SelectableText(
                e.toString(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: stackTrace.toString()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error details copied to clipboard'),
                    ),
                  );
                },
                child: const Text('Copy Error Details'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _bottomNavScreens = [
      _buildMapView(),
      const JobListScreen(),
      const HistoryScreen(),
      const WalletScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _bottomNavIndex == 0
                  ? 'Nearby Jobs (${nearbyJobs.length})'
                  : _bottomNavIndex == 1
                  ? 'Job List'
                  : _bottomNavIndex == 2
                  ? 'History'
                  : 'Wallet',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _currentStatus,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: _isOnline ? const Color(0xFF667eea) : Colors.grey,
        foregroundColor: Colors.white,
        actions: [
          if (_bottomNavIndex == 0)
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JobListScreen()),
              ),
            ),
          if (_bottomNavIndex == 0)
            IconButton(
              icon: Icon(_isOnline ? Icons.location_on : Icons.location_off),
              onPressed: _toggleOnlineStatus,
            ),
          // Sound settings button
          if (_bottomNavIndex == 0)
            PopupMenuButton(
              icon: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: StatefulBuilder(
                    builder: (context, setState) => Row(
                      children: [
                        Icon(
                          _soundEnabled
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                        ),
                        const SizedBox(width: 8),
                        const Text('Enable Sound Alerts'),
                        const Spacer(),
                        Switch(
                          value: _soundEnabled,
                          onChanged: (value) async {
                            setState(() => _soundEnabled = value);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('sound_enabled', value);

                            // Test sound when enabling
                            if (value) {
                              _testCustomSound();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuItem(
                  child: Row(
                    children: [
                      const Icon(Icons.music_note),
                      const SizedBox(width: 8),
                      const Text('Test Sound'),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: _testCustomSound,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _bottomNavIndex, children: _bottomNavScreens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _bottomNavIndex,
        selectedItemColor: const Color(0xFF667eea),
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => _bottomNavIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'List'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: currentLatLng != null
              ? CameraPosition(target: currentLatLng!, zoom: 14)
              : const CameraPosition(target: LatLng(-17.8249, 31.05), zoom: 11),
          markers: markers,
          polylines: polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          onMapCreated: (controller) {
            mapController = controller;
            if (currentLatLng != null) {
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(currentLatLng!, 14),
              );
            }
          },
        ),
        if (!_isOnline)
          Container(
            color: Colors.black54,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'You are OFFLINE\nTap the location icon to go online',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
      ],
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_bottomNavIndex != 0) return null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_jobStatus != 'None' && _currentJob != null)
          FloatingActionButton.extended(
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Status: $_jobStatus')));
            },
            backgroundColor: Colors.orange,
            label: Text(_jobStatus),
            icon: const Icon(Icons.info),
          ),
        const SizedBox(height: 12),
        FloatingActionButton(
          onPressed: _getCurrentLocation,
          backgroundColor: const Color(0xFF667eea),
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              _userName,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              _userPhone.isNotEmpty ? _userPhone : _currentStatus,
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            currentAccountPicture: GestureDetector(
              onTap: () {
                // Optional: open profile edit
              },
              child: CircleAvatar(
                radius: 35,
                backgroundImage: _profileImage != null
                    ? NetworkImage(
                        'https://chareta.com/riderhub/api/$_profileImage',
                      )
                    : null,
                child: _profileImage == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isOnline
                    ? [const Color(0xFF667eea), const Color(0xFF764ba2)]
                    : [Colors.grey, Colors.grey.shade700],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Home'),
                  onTap: () => Navigator.pop(context),
                ),
                CurrentJobTile(),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: const Text('Wallet'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Help & Support'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HelpSupportScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          userName: _userName,
                          userPhone: _userPhone,
                          onProfileUpdated: (newName, newPhone) {
                            setState(() {
                              _userName = newName;
                              _userPhone = newPhone;
                            });
                            SharedPreferences.getInstance().then((prefs) {
                              prefs.setString('user_name', newName);
                              prefs.setString('user_phone', newPhone);
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('History'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                ),
                const Divider(),
                // Sound settings in drawer
                // ListTile(
                //   leading: Icon(
                //     _soundEnabled ? Icons.volume_up : Icons.volume_off,
                //   ),
                //   title: const Text('Custom Sound Alerts'),
                //   subtitle: const Text('Play MP3 sound for new jobs'),
                //   trailing: Switch(
                //     value: _soundEnabled,
                //     onChanged: (value) async {
                //       setState(() => _soundEnabled = value);
                //       final prefs = await SharedPreferences.getInstance();
                //       await prefs.setBool('sound_enabled', value);

                //       // Test sound when enabling
                //       if (value) {
                //         _testCustomSound();
                //       }
                //     },
                //   ),
                // ),
                // ListTile(
                //   leading: const Icon(Icons.music_note),
                //   title: const Text('Test Sound'),
                //   onTap: _testCustomSound,
                // ),
                // const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: const Text('Logout'),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _toggleOnlineStatus,
              icon: Icon(_isOnline ? Icons.check_circle : Icons.motorcycle),
              label: Text(
                _isOnline ? 'Online' : 'Go Online',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isOnline
                    ? Colors.green
                    : const Color(0xFF667eea),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    }
  }
}
