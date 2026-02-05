// job_list_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class JobListScreen extends StatefulWidget {
  const JobListScreen({super.key});

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  Position? _currentPosition;
  String _filterType = 'all';
  String _sortBy = 'distance';

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndLoadJobs();
  }

  Future<void> _getCurrentLocationAndLoadJobs() async {
    try {
      // Get current location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Load jobs from API
      await _loadJobsFromAPI();
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadJobsFromAPI() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Build URL with current location if available
      String url =
          'https://chareta.com/riderhub/api/api.php?action=requests_nearby';

      if (_currentPosition != null) {
        url +=
            '&lat=${_currentPosition!.latitude}&lng=${_currentPosition!.longitude}&radius=50';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Session-Id': sessionId,
          'Content-Type': 'application/json',
        },
      );

      debugPrint('API Response Status: ${response.statusCode}');
      debugPrint('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['error'] != null) {
          debugPrint('API Error: ${data['error']}');
          setState(() => _isLoading = false);
          return;
        }

        if (data['requests'] != null) {
          List<Map<String, dynamic>> jobs = [];

          for (var request in data['requests']) {
            // Calculate distance from rider to pickup location
            double distance = _currentPosition != null
                ? _calculateDistance(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    double.parse(request['pickup_lat'].toString()),
                    double.parse(request['pickup_lng'].toString()),
                  )
                : double.parse(request['distance']?.toString() ?? '0');

            // Determine job type based on parcel size
            String jobType = _getJobType(request['parcel_size']);

            jobs.add({
              'id': request['id'].toString(),
              'title': '${request['parcel_size']} Package Delivery',
              'description': 'Delivery request #${request['id']}',
              'distance': '${distance.toStringAsFixed(1)} km',
              'distanceValue': distance,
              'fare': double.parse(
                request['suggested_fare']?.toString() ?? '0',
              ),
              'customerPrice': double.parse(
                request['suggested_fare']?.toString() ?? '0',
              ),
              'urgency': 'Normal',
              'type': jobType,
              'pickup_lat': double.parse(request['pickup_lat'].toString()),
              'pickup_lng': double.parse(request['pickup_lng'].toString()),
              'dropoff_lat': double.parse(request['dropoff_lat'].toString()),
              'dropoff_lng': double.parse(request['dropoff_lng'].toString()),
              'parcel_size': request['parcel_size'],
              'payment_method': request['payment_method'],
              'created_at': request['created_at'],
            });
          }

          // Sort by distance
          jobs.sort((a, b) => a['distanceValue'].compareTo(b['distanceValue']));

          setState(() {
            _jobs = jobs;
            _isLoading = false;
          });
          _debugPrintJobData(jobs);
        } else {
          debugPrint('No requests found in response');
          setState(() {
            _jobs = [];
            _isLoading = false;
          });
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Load jobs error: $e');
      setState(() {
        _jobs = [];
        _isLoading = false;
      });
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  String _getJobType(String parcelSize) {
    switch (parcelSize.toLowerCase()) {
      case 'small':
        return 'Package';
      case 'medium':
        return 'Document';
      case 'large':
        return 'Furniture';
      default:
        return 'Package';
    }
  }

  void _showRouteOnMap(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RouteMapScreen(job: job, currentPosition: _currentPosition!),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredJobs {
    List<Map<String, dynamic>> filtered = List.from(_jobs);

    // Apply type filter
    if (_filterType != 'all') {
      filtered = filtered.where((job) => job['type'] == _filterType).toList();
    }

    // Apply sorting
    if (_sortBy == 'distance') {
      filtered.sort((a, b) => a['distanceValue'].compareTo(b['distanceValue']));
    } else if (_sortBy == 'fare') {
      filtered.sort((a, b) => b['fare'].compareTo(a['fare']));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Available Jobs',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadJobsFromAPI,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No jobs available',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for new delivery requests',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Summary bar
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_filteredJobs.length} jobs found',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // if (_currentPosition != null)
                      //   Text(
                      //     'Your location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                      //     style: GoogleFonts.inter(
                      //       fontSize: 12,
                      //       color: Colors.grey.shade600,
                      //     ),
                      //   ),
                    ],
                  ),
                ),
                // Jobs list
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredJobs.length,
                    itemBuilder: (context, index) {
                      final job = _filteredJobs[index];
                      return _buildJobCard(job);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getTypeColor(job['type']),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getTypeIcon(job['type']), color: Colors.white),
        ),
        title: Text(
          job['title'],
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Text(
            //   'From: ${job['pickup_lat'].toStringAsFixed(4)}, ${job['pickup_lng'].toStringAsFixed(4)}',
            //   style: GoogleFonts.inter(fontSize: 12),
            // ),
            // Text(
            //   'To: ${job['dropoff_lat'].toStringAsFixed(4)}, ${job['dropoff_lng'].toStringAsFixed(4)}',
            //   style: GoogleFonts.inter(fontSize: 12),
            // ),
            // const SizedBox(height: 4),
            Row(
              children: [
                // Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                // const SizedBox(width: 4),
                // Text(
                //   job['distance'],
                //   style: GoogleFonts.inter(
                //     fontSize: 12,
                //     color: Colors.grey.shade600,
                //   ),
                // ),
                const SizedBox(width: 16),
                Icon(Icons.payment, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  job['payment_method'],
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${job['fare'].toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF667eea),
              ),
            ),
            Text(
              job['parcel_size'],
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        onTap: () => _showJobDetails(job),
      ),
    );
  }

  void _showJobDetails(Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                job['title'],
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Parcel Size', job['parcel_size']),
              // _buildDetailRow('Distance', job['distance']),
              _buildDetailRow('Payment', job['payment_method']),
              _buildDetailRow('Type', job['type']),
              _buildDetailRow('Created', _formatDate(job['created_at'])),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer Offer',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '\$${job['fare'].toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // const SizedBox(height: 20),
              // Row(
              //   children: [
              //     Expanded(
              //       child: ElevatedButton(
              //         onPressed: () {
              //           Navigator.pop(context);
              //           _showRouteOnMap(job);
              //         },
              //         style: ElevatedButton.styleFrom(
              //           backgroundColor: const Color(0xFF667eea),
              //           padding: const EdgeInsets.symmetric(vertical: 12),
              //         ),
              //         child: const Text(
              //           'View Route',
              //           style: TextStyle(color: Colors.white),
              //         ),
              //       ),
              //     ),
              //     const SizedBox(width: 12),
              //     Expanded(
              //       child: ElevatedButton(
              //         onPressed: () {
              //           Navigator.pop(context);
              //           _acceptJob(job, job['fare']);
              //         },
              //         style: ElevatedButton.styleFrom(
              //           backgroundColor: Colors.green,
              //           padding: const EdgeInsets.symmetric(vertical: 12),
              //         ),
              //         child: Text(
              //           'Accept \$${job['fare'].toStringAsFixed(2)}',
              //           style: const TextStyle(color: Colors.white),
              //         ),
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _acceptJob(Map<String, dynamic> job, double acceptedFare) {
    // In a real app, this would communicate with your backend to create an offer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Job accepted! Fare: \$$acceptedFare'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate to route view
    Future.delayed(const Duration(seconds: 1), () {
      _showRouteOnMap(job);
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Filter & Sort Jobs'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Filter by type
                const Text('Filter by Type:'),
                DropdownButton<String>(
                  value: _filterType,
                  onChanged: (newValue) {
                    setState(() => _filterType = newValue!);
                  },
                  items: ['all', 'Package', 'Document', 'Furniture'].map((
                    type,
                  ) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type == 'all' ? 'All Types' : type),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Sort by
                const Text('Sort by:'),
                DropdownButton<String>(
                  value: _sortBy,
                  onChanged: (newValue) {
                    setState(() => _sortBy = newValue!);
                  },
                  items: [
                    DropdownMenuItem(
                      value: 'distance',
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 8),
                          const Text('Distance (Nearest)'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'fare',
                      child: Row(
                        children: [
                          const Icon(Icons.attach_money, size: 16),
                          const SizedBox(width: 8),
                          const Text('Fare (Highest)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterType = 'all';
                    _sortBy = 'distance';
                  });
                  Navigator.pop(context);
                  _loadJobsFromAPI();
                },
                child: const Text('Reset'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {});
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Document':
        return Colors.blue;
      case 'Furniture':
        return Colors.brown;
      default:
        return const Color(0xFF667eea);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Document':
        return Icons.description;
      case 'Furniture':
        return Icons.chair;
      default:
        return Icons.local_shipping;
    }
  }

  void _debugPrintJobData(List<Map<String, dynamic>> jobs) {
    debugPrint('=== JOBS DATA ===');
    debugPrint('Total jobs: ${jobs.length}');
    for (var job in jobs) {
      debugPrint('Job ID: ${job['id']}');
      debugPrint('Title: ${job['title']}');
      debugPrint('Fare: \$${job['fare']}');
      debugPrint('Distance: ${job['distance']}');
      debugPrint('---');
    }
    debugPrint('=== END JOBS DATA ===');
  }
}

// Route Map Screen
class RouteMapScreen extends StatelessWidget {
  final Map<String, dynamic> job;
  final Position currentPosition;

  const RouteMapScreen({
    super.key,
    required this.job,
    required this.currentPosition,
  });

  @override
  Widget build(BuildContext context) {
    final LatLng pickup = LatLng(job['pickup_lat'], job['pickup_lng']);
    final LatLng dropoff = LatLng(job['dropoff_lat'], job['dropoff_lng']);
    final LatLng riderPosition = LatLng(
      currentPosition.latitude,
      currentPosition.longitude,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Route'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
        markers: {
          Marker(
            markerId: const MarkerId('rider'),
            position: riderPosition,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
          Marker(
            markerId: const MarkerId('pickup'),
            position: pickup,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: const InfoWindow(title: 'Pickup Location'),
          ),
          Marker(
            markerId: const MarkerId('dropoff'),
            position: dropoff,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: const InfoWindow(title: 'Dropoff Location'),
          ),
        },
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: [riderPosition, pickup, dropoff],
            color: Colors.blue,
            width: 4,
          ),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Start navigation (in real app, this would open Google Maps)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Starting navigation to pickup location...'),
            ),
          );
        },
        backgroundColor: const Color(0xFF667eea),
        child: const Icon(Icons.navigation, color: Colors.white),
      ),
    );
  }
}
