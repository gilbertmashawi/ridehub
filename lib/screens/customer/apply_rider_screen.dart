// lib/screens/customer/apply_rider_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:riderhub/screens/rider/rider_status_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class ApplyRiderScreen extends StatefulWidget {
  const ApplyRiderScreen({super.key});

  @override
  State<ApplyRiderScreen> createState() => _ApplyRiderScreenState();
}

class _ApplyRiderScreenState extends State<ApplyRiderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isCheckingStatus = false;
  String? _sessionId;
  String? _applicationStatus;
  String? _riderCode;
  String? _rejectionReason;

  // Form Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _vehicleTypeController = TextEditingController();
  final TextEditingController _vehicleModelController = TextEditingController();
  final TextEditingController _vehicleYearController = TextEditingController();
  final TextEditingController _vehicleRegController = TextEditingController();
  final TextEditingController _licenseNumberController =
      TextEditingController();

  // Images
  Uint8List? _idFrontBytes;
  Uint8List? _idBackBytes;
  Uint8List? _vehicleFrontBytes;
  Uint8List? _vehicleBackBytes;
  Uint8List? _licenseBytes;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadValidSessionAndCheckStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameController.dispose();
    _idNumberController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _vehicleTypeController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleRegController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  void _addDebug(String message) {
    final time = DateTime.now().toString().substring(11, 23);
    final line = '[$time] $message';
    debugPrint('APPLY_RIDER_DEBUG: $line');
  }

  // AUTO-FIXES SESSION + CHECKS STATUS
  Future<void> _loadValidSessionAndCheckStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedSession = prefs.getString('session_id');
    final int? savedUserId = prefs.getInt('user_id');

    _addDebug('Initial - Session: $savedSession, UserId: $savedUserId');

    // If we don't have a proper session but have user_id, try to recover
    if ((savedSession == null || savedSession.length < 20) &&
        savedUserId != null) {
      _addDebug('Attempting session recovery for user: $savedUserId');
      try {
        final response = await http
            .get(
              Uri.parse(
                'https://chareta.com/riderhub/api/api.php?action=get_session',
              ),
              headers: {'X-User-Id': savedUserId.toString()},
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final realSession = data['session_id']?.toString();
          if (realSession != null && realSession.length > 20) {
            await prefs.setString('session_id', realSession);
            savedSession = realSession;
            _addDebug('Session recovery SUCCESS: $realSession');
          }
        }
      } catch (e) {
        _addDebug('Session recovery failed: $e');
      }
    }

    // Final session determination
    _sessionId = savedSession;

    if (_sessionId == null || _sessionId!.trim().isEmpty) {
      _showError('Login session lost. Please restart app and login again.');
      return;
    }

    _addDebug('Final session ID: $_sessionId (length: ${_sessionId?.length})');
    setState(() {});

    await _checkApplicationStatus();
  }

  Future<void> _checkApplicationStatus() async {
    if (_sessionId == null || _sessionId!.isEmpty) return;
    setState(() => _isCheckingStatus = true);

    try {
      final response = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=rider_application_status',
        ),
        headers: {'X-Session-Id': _sessionId!},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status']?.toString().toLowerCase();
        setState(() {
          if (status == 'pending' ||
              status == 'approved' ||
              status == 'rejected') {
            _applicationStatus = status;
            _riderCode = data['rider_code']?.toString();
            _rejectionReason = data['rejection_reason'];
          } else {
            _applicationStatus = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Status check error: $e');
    } finally {
      setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _submitApplication() async {
    // FORCE RECOVER REAL SESSION BEFORE ANYTHING
    await _loadValidSessionAndCheckStatus();

    if (_sessionId == null || _sessionId!.trim().isEmpty) {
      _showError('Cannot submit: Invalid session. Restart app and try again.');
      return;
    }

    // Rest of validation...
    if (_fullNameController.text.trim().isEmpty ||
        _idNumberController.text.trim().isEmpty ||
        _vehicleTypeController.text.trim().isEmpty ||
        _vehicleRegController.text.trim().isEmpty ||
        _idFrontBytes == null ||
        _idBackBytes == null ||
        _vehicleFrontBytes == null ||
        _vehicleBackBytes == null) {
      _showError('Please complete all required fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=apply_rider',
        ),
      );

      // THIS WILL NOW BE THE REAL LONG SESSION
      request.headers['X-Session-Id'] = _sessionId!;

      // Add form fields
      request.fields.addAll({
        'full_name': _fullNameController.text.trim(),
        'id_number': _idNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'emergency_contact': _emergencyContactController.text.trim(),
        'vehicle_type': _vehicleTypeController.text.trim(),
        'vehicle_model': _vehicleModelController.text.trim(),
        'vehicle_year': _vehicleYearController.text.trim(),
        'vehicle_registration': _vehicleRegController.text.trim(),
        'license_number': _licenseNumberController.text.trim(),
      });

      _addDebug('Form fields: ${request.fields}');

      final images = {
        'id_front_image': _idFrontBytes,
        'id_back_image': _idBackBytes,
        'vehicle_front_image': _vehicleFrontBytes,
        'vehicle_back_image': _vehicleBackBytes,
        'license_image': _licenseBytes,
      };

      images.forEach((key, bytes) {
        if (bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(key, bytes, filename: '$key.jpg'),
          );
          _addDebug('Added image: $key (${bytes.length} bytes)');
        }
      });

      _addDebug('Sending request with ${request.files.length} images');
      _addDebug('Session ID: $_sessionId');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 80),
      );

      final responseBody = await streamedResponse.stream.bytesToString();
      final statusCode = streamedResponse.statusCode;

      _addDebug('Response Status: $statusCode');
      _addDebug('Response Body: $responseBody');

      if (statusCode == 200) {
        try {
          final data = jsonDecode(responseBody);
          _addDebug('Parsed JSON: $data');

          if (data['success'] == true || data['rider_code'] != null) {
            final riderCode = data['rider_code'] ?? 'RDR-???';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('rider_code', riderCode);

            if (mounted) {
              // After successful application, redirect to status screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RiderStatusScreen()),
              );
            }
          } else {
            final errorMsg =
                data['error'] ?? data['message'] ?? 'Unknown error from server';
            _showError('Submission failed: $errorMsg');
          }
        } catch (e) {
          _addDebug('JSON Parse Error: $e');
          _showError('Server response format error: $e');
        }
      } else {
        _showError('Server error $statusCode: $responseBody');
      }
    } catch (e) {
      _addDebug('Exception: $e');
      _showError('Network error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 10),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          switch (type) {
            case 'id_front':
              _idFrontBytes = bytes;
              break;
            case 'id_back':
              _idBackBytes = bytes;
              break;
            case 'vehicle_front':
              _vehicleFrontBytes = bytes;
              break;
            case 'vehicle_back':
              _vehicleBackBytes = bytes;
              break;
            case 'license':
              _licenseBytes = bytes;
              break;
          }
        });
      }
    } catch (e) {
      _showError('Image pick failed: $e');
    }
  }

  void _removeImage(String type) {
    setState(() {
      switch (type) {
        case 'id_front':
          _idFrontBytes = null;
          break;
        case 'id_back':
          _idBackBytes = null;
          break;
        case 'vehicle_front':
          _vehicleFrontBytes = null;
          break;
        case 'vehicle_back':
          _vehicleBackBytes = null;
          break;
        case 'license':
          _licenseBytes = null;
          break;
      }
    });
  }

  void _showImageSourceDialog(String type) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, type);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(
    Uint8List? bytes,
    String type, {
    String label = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(label, style: GoogleFonts.inter(fontSize: 14)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showImageSourceDialog(type),
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: bytes == null
                    ? Colors.grey.shade400
                    : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: bytes != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _removeImage(type),
                          child: const CircleAvatar(
                            backgroundColor: Colors.red,
                            radius: 14,
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 40,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload',
                        style: GoogleFonts.inter(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _idNumberController,
            decoration: const InputDecoration(
              labelText: 'ID Number *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emergencyContactController,
            decoration: const InputDecoration(
              labelText: 'Emergency Contact',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),
          const Text(
            'ID Photos *',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildImagePreview(
                  _idFrontBytes,
                  'id_front',
                  label: 'Front Side *',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildImagePreview(
                  _idBackBytes,
                  'id_back',
                  label: 'Back Side *',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _tabController.animateTo(1),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text(
              'Next: Vehicle Details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _vehicleTypeController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Type * (e.g. Motorcycle)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehicleModelController,
            decoration: const InputDecoration(
              labelText: 'Model',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehicleYearController,
            decoration: const InputDecoration(
              labelText: 'Year',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehicleRegController,
            decoration: const InputDecoration(
              labelText: 'Registration Number *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _licenseNumberController,
            decoration: const InputDecoration(
              labelText: 'License Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Vehicle Photos *',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildImagePreview(
            _vehicleFrontBytes,
            'vehicle_front',
            label: 'Front View *',
          ),
          const SizedBox(height: 16),
          _buildImagePreview(
            _vehicleBackBytes,
            'vehicle_back',
            label: 'Back View *',
          ),
          const SizedBox(height: 16),
          _buildImagePreview(
            _licenseBytes,
            'license',
            label: 'Driving License',
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _tabController.animateTo(0),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _tabController.animateTo(2),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Next: Review'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Your Application',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _reviewItem('Full Name', _fullNameController.text),
          _reviewItem('ID Number', _idNumberController.text),
          _reviewItem('Vehicle Type', _vehicleTypeController.text),
          _reviewItem('Registration', _vehicleRegController.text),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Application',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? 'Not provided' : value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // REDIRECT USERS WHO HAVE ALREADY APPLIED - COMPLETELY HIDE APPLICATION FORM
    if (_applicationStatus != null && _applicationStatus != 'not_applied') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RiderStatusScreen()),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isCheckingStatus) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply to be a Rider'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_tabController.index + 1) / 3,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Personal'),
                  Tab(text: 'Vehicle'),
                  Tab(text: 'Review'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPersonalDetailsTab(),
          _buildVehicleDetailsTab(),
          _buildReviewTab(),
        ],
      ),
    );
  }
}
