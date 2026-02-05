// New lib/screens/rider/delivery_detail_screen.dart
// For navigation, status updates, upload proof
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DeliveryDetailScreen extends StatefulWidget {
  final String requestId;
  final double fare;

  const DeliveryDetailScreen({
    super.key,
    required this.requestId,
    this.fare = 0.0,
  });

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  String _currentStatus = 'Accepted'; // Accepted → Picked Up → Delivered
  File? _proofPhoto;
  final TextEditingController _receiverNameController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng _pickupPosition = const LatLng(-17.8179, 31.0469); // Dummy

  @override
  void initState() {
    super.initState();
    _getPickupLocation();
  }

  Future<void> _getPickupLocation() async {
    // Use Geolocator to get directions, but for lite: open Google Maps app
    // For in-app lite map
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _pickupPosition = LatLng(position.latitude, position.longitude);
    });
  }

  void _updateStatus(String newStatus) {
    setState(() {
      _currentStatus = newStatus;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
    if (newStatus == 'Delivered') {
      _showProofUploadDialog();
    }
  }

  Future<void> _pickProofPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _proofPhoto = File(image.path);
      });
    }
  }

  void _showProofUploadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Proof of Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _pickProofPhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
            if (_proofPhoto != null) Image.file(_proofPhoto!, height: 100),
            TextFormField(
              controller: _receiverNameController,
              decoration: const InputDecoration(
                labelText: 'Receiver Name/Signature',
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
              if (_proofPhoto != null &&
                  _receiverNameController.text.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Proof uploaded! Delivery complete.'),
                  ),
                );
                Navigator.pop(context);
                Navigator.pop(context); // Back to home
              }
            },
            child: const Text('Submit Proof'),
          ),
        ],
      ),
    );
  }

  void _navigateToPickup() {
    // Lite navigation: Open Google Maps URL
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${_pickupPosition.latitude},${_pickupPosition.longitude}';
    // Use url_launcher to open (add dependency)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigating to pickup... (Open Google Maps)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Delivery #${widget.requestId}',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatusChip('Accepted', _currentStatus == 'Accepted'),
                _buildStatusChip('Picked Up', _currentStatus == 'Picked Up'),
                _buildStatusChip('Delivered', _currentStatus == 'Delivered'),
              ],
            ),
            const SizedBox(height: 16),
            // Map (lite: smaller height)
            Container(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _pickupPosition,
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: _pickupPosition,
                  ),
                },
                onMapCreated: (controller) => _mapController = controller,
              ),
            ),
            const SizedBox(height: 16),
            // Fare
            Text(
              'Fare: \$${widget.fare}',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF667eea),
              ),
            ),
            const SizedBox(height: 24),
            // Action Buttons
            if (_currentStatus == 'Accepted')
              ElevatedButton.icon(
                onPressed: _navigateToPickup,
                icon: const Icon(Icons.navigation),
                label: const Text('Navigate to Pickup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            if (_currentStatus == 'Accepted' || _currentStatus == 'Picked Up')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(
                    _currentStatus == 'Accepted' ? 'Picked Up' : 'Delivered',
                  ),
                  icon: const Icon(Icons.update),
                  label: Text(
                    'Update to ${_currentStatus == 'Accepted' ? 'Picked Up' : 'Delivered'}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? Colors.green : Colors.grey),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}
