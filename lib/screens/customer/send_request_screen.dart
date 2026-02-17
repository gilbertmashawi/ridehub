// Production-Ready SendRequestScreen with improved location UI
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';

class SendRequestScreen extends StatefulWidget {
  const SendRequestScreen({super.key});

  @override
  State<SendRequestScreen> createState() => _SendRequestScreenState();
}

class _SendRequestScreenState extends State<SendRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _parcelSize;
  String? _paymentMethod;
  final TextEditingController _suggestedFareController =
      TextEditingController();
  final TextEditingController _pickupSearchController = TextEditingController();
  final TextEditingController _dropoffSearchController =
      TextEditingController();
  final TextEditingController _pickupAddressController =
      TextEditingController(); // New: Pickup Address
  final TextEditingController _dropoffNoteController =
      TextEditingController(); // New: Dropoff Note

  // Map variables
  GoogleMapController? _mapController;
  LatLng? _pickupPosition;
  LatLng? _dropoffPosition;
  File? _parcelPhoto;

  // Search variables
  bool _showPickupSuggestions = false;
  bool _showDropoffSuggestions = false;
  List<Map<String, dynamic>> _pickupSuggestions = [];
  List<Map<String, dynamic>> _dropoffSuggestions = [];
  bool _isLoadingSuggestions = false;

  // API Configuration
  static const String _googlePlacesApiKey =
      'AIzaSyAEqhpYB-uOW1kwVpyavEEM2V1hPHdCb8g';
  static const String _googleGeocodingApiKey =
      'AIzaSyAEqhpYB-uOW1kwVpyavEEM2V1hPHdCb8g';

  // Default Harare position
  static const LatLng _harare = LatLng(-17.8249, 31.0469);

  bool _isLoading = false;
  FocusNode _pickupFocusNode = FocusNode();
  FocusNode _dropoffFocusNode = FocusNode();

  // UI state
  bool _showDetailsForm = false;
  ScrollController _scrollController = ScrollController();
  double _mapHeight = 400;

  // Debounce timer for search
  Timer? _searchDebounce;

  // UI state for location cards
  bool _isPickupExpanded = false;
  bool _isDropoffExpanded = false;
  bool _isLocationSearchFloating = false;

  @override
  void initState() {
    super.initState();
    // Removed automatic _getCurrentLocationForPickup() to allow manual selection

    // Add listeners for focus changes
    _pickupFocusNode.addListener(() {
      if (_pickupFocusNode.hasFocus) {
        setState(() {
          _showPickupSuggestions = _pickupSearchController.text.isNotEmpty;
          _isPickupExpanded = true;
          _isLocationSearchFloating = true;
        });
      } else if (!_pickupFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_dropoffFocusNode.hasFocus) {
            setState(() {
              _showPickupSuggestions = false;
              _isPickupExpanded = false;
            });
          }
        });
      }
    });

    _dropoffFocusNode.addListener(() {
      if (_dropoffFocusNode.hasFocus) {
        setState(() {
          _showDropoffSuggestions = _dropoffSearchController.text.isNotEmpty;
          _isDropoffExpanded = true;
          _isLocationSearchFloating = true;
        });
      } else if (!_dropoffFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_pickupFocusNode.hasFocus) {
            setState(() {
              _showDropoffSuggestions = false;
              _isDropoffExpanded = false;
            });
          }
        });
      }
    });

    // Listen to scroll to adjust map height
    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      if (offset > 100 && _mapHeight > 300) {
        setState(() {
          _mapHeight = 300;
        });
      } else if (offset <= 100 && _mapHeight < 400) {
        setState(() {
          _mapHeight = 400;
        });
      }
    });
  }

  @override
  void dispose() {
    _pickupSearchController.dispose();
    _dropoffSearchController.dispose();
    _suggestedFareController.dispose();
    _pickupAddressController.dispose(); // New dispose
    _dropoffNoteController.dispose(); // New dispose
    _pickupFocusNode.dispose();
    _dropoffFocusNode.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocationForPickup() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled. Please enable them.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permissions are denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permissions are permanently denied.');
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _pickupPosition = LatLng(position.latitude, position.longitude);
      });
      // Reverse geocode to get address
      await _reverseGeocode(_pickupPosition!, true);
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_pickupPosition!, 15),
        );
      }
    } catch (e) {
      _showSnackBar('Failed to get current location: $e');
    }
  }

  Future<void> _searchPlaces(String query, bool isPickup) async {
    debugPrint('_searchPlaces called: query="$query", isPickup=$isPickup');
    // Cancel previous debounce timer
    _searchDebounce?.cancel();
    if (query.length < 3) {
      setState(() {
        if (isPickup) {
          _showPickupSuggestions = false;
          _pickupSuggestions.clear();
        } else {
          _showDropoffSuggestions = false;
          _dropoffSuggestions.clear();
        }
      });
      return;
    }
    setState(() {
      if (isPickup) {
        _showPickupSuggestions = true;
      } else {
        _showDropoffSuggestions = true;
      }
    });
    // Debounce search to avoid too many API calls
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _performSearch(query, isPickup);
    });
  }

  Future<void> _performSearch(String query, bool isPickup) async {
    try {
      final String apiUrl =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json';
      // Create location bias string
      String locationBias = '';
      LatLng? biasLocation;
      // Use appropriate bias location
      if (isPickup && _pickupPosition != null) {
        biasLocation = _pickupPosition;
      } else if (!isPickup && _dropoffPosition != null) {
        biasLocation = _dropoffPosition;
      } else if (_pickupPosition != null) {
        biasLocation = _pickupPosition;
      }
      if (biasLocation != null) {
        locationBias =
            '&location=${biasLocation.latitude},${biasLocation.longitude}&radius=50000';
      }
      final String url =
          '$apiUrl?input=$query&key=$_googlePlacesApiKey$locationBias&components=country:zw';
      debugPrint('🔍 Searching places for: $query');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('API Response: ${data['status']}');
        if (data['status'] == 'OK') {
          List<Map<String, dynamic>> suggestions = [];
          // Get suggestions first (without details)
          for (var prediction in data['predictions']) {
            suggestions.add({
              'description': prediction['description'],
              'place_id': prediction['place_id'],
              'structured_formatting': prediction['structured_formatting'],
              'lat': null, // Will be filled later
              'lng': null,
            });
          }
          setState(() {
            if (isPickup) {
              _pickupSuggestions = suggestions;
            } else {
              _dropoffSuggestions = suggestions;
            }
            _isLoadingSuggestions = false;
          });
          // Get coordinates for first 3 suggestions (optimization)
          for (int i = 0; i < suggestions.length && i < 3; i++) {
            final placeDetails = await _getPlaceDetails(
              suggestions[i]['place_id'],
            );
            if (placeDetails != null) {
              setState(() {
                if (isPickup && i < _pickupSuggestions.length) {
                  _pickupSuggestions[i]['lat'] = placeDetails['lat'];
                  _pickupSuggestions[i]['lng'] = placeDetails['lng'];
                } else if (!isPickup && i < _dropoffSuggestions.length) {
                  _dropoffSuggestions[i]['lat'] = placeDetails['lat'];
                  _dropoffSuggestions[i]['lng'] = placeDetails['lng'];
                }
              });
            }
          }
        } else {
          debugPrint('Places API error: ${data['status']}');
          setState(() {
            _isLoadingSuggestions = false;
          });
        }
      } else {
        throw Exception('Failed to load places');
      }
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _isLoadingSuggestions = false;
      });
      _showSnackBar('Search failed. Please check your connection.');
    }
  }

  Future<void> _searchWithOpenStreetMap(String query, bool isPickup) async {
    debugPrint(
      '_searchWithOpenStreetMap called: query="$query", isPickup=$isPickup',
    );
    if (query.length < 3) {
      setState(() {
        if (isPickup) {
          _showPickupSuggestions = false;
          _pickupSuggestions.clear();
        } else {
          _showDropoffSuggestions = false;
          _dropoffSuggestions.clear();
        }
      });
      return;
    }
    setState(() {
      _isLoadingSuggestions = true;
    });
    try {
      final String apiUrl = 'https://nominatim.openstreetmap.org/search';
      final String url =
          '$apiUrl?format=json&q=${Uri.encodeComponent(query)}&countrycodes=zw&limit=10&addressdetails=1';
      debugPrint('🌍 OpenStreetMap search URL: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'RiderHubApp/1.0'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> suggestions = [];
        for (var place in data) {
          String displayName = place['display_name'];
          // Truncate very long display names
          if (displayName.length > 100) {
            displayName = displayName.substring(0, 100) + '...';
          }
          suggestions.add({
            'description': displayName,
            'lat': double.parse(place['lat']),
            'lng': double.parse(place['lon']),
            'type': place['type'],
            'osm_id': place['osm_id'],
            'importance': place['importance'] ?? 0.0,
          });
        }
        setState(() {
          if (isPickup) {
            _pickupSuggestions = suggestions;
            _showPickupSuggestions = true;
          } else {
            _dropoffSuggestions = suggestions;
            _showDropoffSuggestions = true;
          }
          _isLoadingSuggestions = false;
        });
        debugPrint('✅ Found ${suggestions.length} suggestions');
      } else {
        debugPrint('❌ OpenStreetMap error: ${response.statusCode}');
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      debugPrint('❌ OpenStreetMap search error: $e');
      setState(() {
        _isLoadingSuggestions = false;
      });
      // Fall back to Google if available
      if (_googlePlacesApiKey.isNotEmpty &&
          _googlePlacesApiKey != 'AIzaSyAEqhpYB-uOW1kwVpyavEEM2V1hPHdCb8g') {
        await _performSearch(query, isPickup);
      }
    }
  }

  Future<Map<String, dynamic>?> _getPlaceDetails(String placeId) async {
    try {
      final String apiUrl =
          'https://maps.googleapis.com/maps/api/place/details/json';
      final String url =
          '$apiUrl?place_id=$placeId&key=$_googlePlacesApiKey&fields=geometry';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          return {'lat': location['lat'], 'lng': location['lng']};
        }
      }
      return null;
    } catch (e) {
      debugPrint('Place details error: $e');
      return null;
    }
  }

  Future<void> _reverseGeocode(LatLng position, bool isPickup) async {
    try {
      final String apiUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
      final String url =
          '$apiUrl?latlng=${position.latitude},${position.longitude}&key=$_googleGeocodingApiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          String address = data['results'][0]['formatted_address'];
          if (isPickup) {
            _pickupSearchController.text = address;
          } else {
            _dropoffSearchController.text = address;
          }
        } else {
          // Fallback to coordinates
          String address =
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          if (isPickup) {
            _pickupSearchController.text = address;
          } else {
            _dropoffSearchController.text = address;
          }
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
      // Fallback to coordinates
      String address =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      if (isPickup) {
        _pickupSearchController.text = address;
      } else {
        _dropoffSearchController.text = address;
      }
    }
  }

  Future<void> _forwardGeocode(String address, bool isPickup) async {
    try {
      final String apiUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
      final String url =
          '$apiUrl?address=${Uri.encodeComponent(address)}&key=$_googleGeocodingApiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final position = LatLng(location['lat'], location['lng']);
          setState(() {
            if (isPickup) {
              _pickupPosition = position;
            } else {
              _dropoffPosition = position;
            }
          });
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(position, 15),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Forward geocode error: $e');
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion, bool isPickup) {
    final lat = suggestion['lat'];
    final lng = suggestion['lng'];
    final address = suggestion['description'];
    // Check if we have coordinates (OpenStreetMap provides them directly)
    if (lat != null && lng != null) {
      final position = LatLng(lat, lng);
      setState(() {
        if (isPickup) {
          _pickupPosition = position;
          _pickupSearchController.text = address;
          _showPickupSuggestions = false;
          _isPickupExpanded = false;
          _isLocationSearchFloating = false;
        } else {
          _dropoffPosition = position;
          _dropoffSearchController.text = address;
          _showDropoffSuggestions = false;
          _isDropoffExpanded = false;
          _isLocationSearchFloating = false;
        }
      });
      // Move camera to selected location
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
      }
    } else {
      // For Google Places without coordinates yet, geocode the address
      _forwardGeocode(address, isPickup);
      setState(() {
        if (isPickup) {
          _pickupSearchController.text = address;
          _showPickupSuggestions = false;
          _isPickupExpanded = false;
          _isLocationSearchFloating = false;
        } else {
          _dropoffSearchController.text = address;
          _showDropoffSuggestions = false;
          _isDropoffExpanded = false;
          _isLocationSearchFloating = false;
        }
      });
    }
    // Clear focus
    if (isPickup) {
      _pickupFocusNode.unfocus();
    } else {
      _dropoffFocusNode.unfocus();
    }
  }

  void _useCurrentLocation(bool isPickup) async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = LatLng(position.latitude, position.longitude);
      await _reverseGeocode(latLng, isPickup);
      setState(() {
        if (isPickup) {
          _pickupPosition = latLng;
          _showPickupSuggestions = false;
          _isPickupExpanded = false;
        } else {
          _dropoffPosition = latLng;
          _showDropoffSuggestions = false;
          _isDropoffExpanded = false;
        }
        _isLocationSearchFloating = false;
      });
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      }
    } catch (e) {
      _showSnackBar('Failed to get current location: $e');
    }
  }

  void _handleMapTap(LatLng position) {
    // Determine which location to update based on which field was last focused
    final pickupHasFocus = _pickupFocusNode.hasFocus;
    final dropoffHasFocus = _dropoffFocusNode.hasFocus;
    if (pickupHasFocus || (!dropoffHasFocus && _pickupPosition == null)) {
      // Update pickup
      _pickupFocusNode.unfocus();
      setState(() {
        _pickupPosition = position;
        _showPickupSuggestions = false;
        _isPickupExpanded = false;
      });
      _reverseGeocode(position, true);
    } else {
      // Update dropoff
      _dropoffFocusNode.unfocus();
      setState(() {
        _dropoffPosition = position;
        _showDropoffSuggestions = false;
        _isDropoffExpanded = false;
      });
      _reverseGeocode(position, false);
    }
    setState(() {
      _isLocationSearchFloating = false;
    });
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(position));
    }
  }

  Future<void> _pickPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _parcelPhoto = File(image.path);
      });
    }
  }

  Future<void> _submitRequest() async {
    debugPrint('=== SUBMIT REQUEST STARTED ===');
    if (_formKey.currentState!.validate() &&
        _pickupPosition != null &&
        _dropoffPosition != null &&
        _parcelSize != null &&
        _paymentMethod != null) {
      debugPrint('✅ All validations passed');
      setState(() {
        _isLoading = true;
      });
      try {
        final sessionId = await _getSessionId();
        if (sessionId == null) {
          _showSnackBar('No session found. Please log in again.');
          setState(() {
            _isLoading = false;
          });
          return;
        }
        // Create multipart request
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://chareta.com/riderhub/api/api.php?action=requests'),
        );
        // Add headers
        request.headers['X-Session-Id'] = sessionId;
        // Add form fields
        request.fields['pickup_lat'] = _pickupPosition!.latitude.toString();
        request.fields['pickup_lng'] = _pickupPosition!.longitude.toString();
        request.fields['dropoff_lat'] = _dropoffPosition!.latitude.toString();
        request.fields['dropoff_lng'] = _dropoffPosition!.longitude.toString();
        request.fields['parcel_size'] = _parcelSize!.toLowerCase();
        request.fields['suggested_fare'] = _suggestedFareController.text.isEmpty
            ? '0'
            : _suggestedFareController.text;
        request.fields['payment_method'] = _paymentMethod!.toLowerCase();
        request.fields['pickup_address'] =
            _pickupAddressController.text; // New field
        request.fields['dropoff_note'] =
            _dropoffNoteController.text; // New field

        // Add parcel photo if available
        if (_parcelPhoto != null) {
          try {
            String extension = _parcelPhoto!.path.split('.').last.toLowerCase();
            String contentType = 'image/jpeg';
            if (extension == 'png') {
              contentType = 'image/png';
            } else if (extension == 'gif') {
              contentType = 'image/gif';
            }
            request.files.add(
              await http.MultipartFile.fromPath(
                'parcel_photo',
                _parcelPhoto!.path,
                filename:
                    'parcel_${DateTime.now().millisecondsSinceEpoch}.$extension',
                contentType: MediaType.parse(contentType),
              ),
            );
          } catch (e) {
            debugPrint('Error adding photo: $e');
          }
        }
        // Send request
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          if (responseData.containsKey('error')) {
            _showSnackBar('Request failed: ${responseData['error']}');
          } else if (responseData.containsKey('request_id')) {
            _showSuccessDialog(
              'Delivery request posted successfully! Waiting for riders...',
            );
          } else {
            _showSnackBar('Unexpected response from server');
          }
        } else if (response.statusCode == 403) {
          await _clearSession();
          _showSnackBar('Session expired. Please log in again.');
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          });
        } else {
          _showSnackBar('Server error: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error: $e');
        _showSnackBar('Network error: Please check your internet connection');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      String errorMessage = 'Please complete the following:\n';
      if (_pickupPosition == null) errorMessage += '• Set pickup location\n';
      if (_dropoffPosition == null) errorMessage += '• Set dropoff location\n';
      if (_parcelSize == null) errorMessage += '• Select parcel size\n';
      if (_paymentMethod == null) errorMessage += '• Select payment method\n';
      if (!_formKey.currentState!.validate())
        errorMessage += '• Fix form errors';
      _showSnackBar(errorMessage);
    }
  }

  // Helper methods
  Future<String?> _getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_id');
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_id');
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
    await prefs.remove('user_type');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success!'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _clearLocation(bool isPickup) {
    setState(() {
      if (isPickup) {
        _pickupPosition = null;
        _pickupSearchController.clear();
        _showPickupSuggestions = false;
        _pickupSuggestions.clear();
        _isPickupExpanded = false;
      } else {
        _dropoffPosition = null;
        _dropoffSearchController.clear();
        _showDropoffSuggestions = false;
        _dropoffSuggestions.clear();
        _isDropoffExpanded = false;
      }
      _isLocationSearchFloating = false;
    });
  }

  Widget _buildFloatingLocationCard({
    required String title,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isPickup,
    required VoidCallback onUseCurrentLocation,
    bool isExpanded = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isExpanded ? 12 : 25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      isExpanded
                          ? TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: hint,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  if (isPickup) {
                                    _pickupSuggestions.clear();
                                  } else {
                                    _dropoffSuggestions.clear();
                                  }
                                  _isLoadingSuggestions = true;
                                });
                                if (_googlePlacesApiKey.isEmpty ||
                                    _googlePlacesApiKey ==
                                        'AIzaSyAEqhpYB-uOW1kwVpyavEEM2V1hPHdCb8g') {
                                  _searchWithOpenStreetMap(value, isPickup);
                                } else {
                                  _searchPlaces(value, isPickup);
                                }
                              },
                            )
                          : Text(
                              controller.text.isEmpty ? hint : controller.text,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: controller.text.isEmpty
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.edit,
                    size: 20,
                    color: Colors.blue,
                  ),
                  onPressed: () {
                    if (isExpanded) {
                      focusNode.unfocus();
                    } else {
                      focusNode.requestFocus();
                    }
                  },
                  tooltip: isExpanded ? 'Collapse' : 'Edit',
                ),
                IconButton(
                  icon: Icon(Icons.my_location, size: 20, color: Colors.blue),
                  onPressed: onUseCurrentLocation,
                  tooltip: 'Use current location',
                ),
              ],
            ),
          ),
          if (isExpanded &&
              ((isPickup && _showPickupSuggestions) ||
                  (!isPickup && _showDropoffSuggestions)))
            _buildCompactSuggestionsList(isPickup),
        ],
      ),
    );
  }

  Widget _buildLocationIndicatorBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildLocationIndicator(
                title: 'Pickup',
                icon: Icons.location_on,
                color: Colors.green,
                isSet: _pickupPosition != null,
                onTap: () {
                  if (_pickupPosition != null) {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_pickupPosition!, 17),
                    );
                  } else {
                    // If pickup not set, focus on pickup input
                    _pickupFocusNode.requestFocus();
                  }
                },
              ),
            ),
            Container(
              width: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_forward,
                    color: Colors.grey.shade400,
                    size: 16,
                  ),
                  Container(height: 2, width: 20, color: Colors.grey.shade300),
                ],
              ),
            ),
            Expanded(
              child: _buildLocationIndicator(
                title: 'Dropoff',
                icon: Icons.location_searching,
                color: Colors.red,
                isSet: _dropoffPosition != null,
                onTap: () {
                  if (_dropoffPosition != null) {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_dropoffPosition!, 17),
                    );
                  } else {
                    // If dropoff not set, focus on dropoff input
                    _dropoffFocusNode.requestFocus();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationIndicator({
    required String title,
    required IconData icon,
    required Color color,
    required bool isSet,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(isSet ? 0.15 : 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(isSet ? 0.5 : 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 14,
                    color: color.withOpacity(isSet ? 1 : 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        isSet ? 'Selected' : 'Tap to set',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSet ? FontWeight.w600 : FontWeight.w400,
                          color: isSet ? color : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSuggestionsList(bool isPickup) {
    final suggestions = isPickup ? _pickupSuggestions : _dropoffSuggestions;
    if (_isLoadingSuggestions) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Text(
          'Type to search locations...',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          final address = suggestion['description'];
          String mainText = address;
          String secondaryText = '';
          if (address.contains(',')) {
            final parts = address.split(',');
            if (parts.length > 1) {
              mainText = parts[0];
              secondaryText = parts.sublist(1).take(2).join(',');
            }
          }
          return ListTile(
            dense: true,
            leading: Icon(
              Icons.location_on,
              color: isPickup ? Colors.green : Colors.red,
              size: 20,
            ),
            title: Text(
              mainText,
              style: GoogleFonts.inter(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: secondaryText.isNotEmpty
                ? Text(
                    secondaryText,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            onTap: () => _selectSuggestion(suggestion, isPickup),
          );
        },
      ),
    );
  }

  Widget _buildMiniLocationControls() {
    return Positioned(
      bottom: 100,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton.small(
            heroTag: 'pickup_fab',
            backgroundColor: Colors.white,
            onPressed: () {
              if (_pickupPosition != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_pickupPosition!, 17),
                );
              } else {
                // If pickup not set, focus on pickup input
                _pickupFocusNode.requestFocus();
              }
            },
            child: Icon(
              Icons.location_on,
              color: _pickupPosition != null ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'dropoff_fab',
            backgroundColor: Colors.white,
            onPressed: () {
              if (_dropoffPosition != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_dropoffPosition!, 17),
                );
              } else {
                // If dropoff not set, focus on dropoff input
                _dropoffFocusNode.requestFocus();
              }
            },
            child: Icon(
              Icons.location_searching,
              color: _dropoffPosition != null ? Colors.red : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Package Details',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              // Pickup Address (New Required Field)
              Text(
                'Pickup Address *',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pickupAddressController,
                decoration: InputDecoration(
                  hintText: 'Enter detailed pickup address',
                  prefixIcon: const Icon(Icons.home),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter pickup address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Parcel Size
              Text(
                'Parcel Size *',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      _buildParcelSizeOption('Small', '🚗', 'small size'),
                      _buildParcelSizeOption('Medium', '🚐', 'medium size'),
                      _buildParcelSizeOption('Large', '🚚', 'large size'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Suggested Fare
              Text(
                'Suggested Fare (USD) *',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _suggestedFareController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter amount you\'re willing to pay',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter suggested fare';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Payment Method
              Text(
                'Payment Method *',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mobile_friendly,
                          color: Colors.green,
                        ),
                      ),
                      title: const Text('EcoCash'),
                      subtitle: const Text('Mobile money payment'),
                      trailing: Radio<String>(
                        value: 'ecocash',
                        groupValue: _paymentMethod,
                        onChanged: (value) =>
                            setState(() => _paymentMethod = value),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.money, color: Colors.blue),
                      ),
                      title: const Text('Cash on Delivery'),
                      subtitle: const Text('Pay when package is delivered'),
                      trailing: Radio<String>(
                        value: 'cash',
                        groupValue: _paymentMethod,
                        onChanged: (value) =>
                            setState(() => _paymentMethod = value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Dropoff Note (New Required Field)
              Text(
                'Dropoff Note *',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dropoffNoteController,
                decoration: InputDecoration(
                  hintText: 'Enter notes for dropoff (e.g., Leave at gate)',
                  prefixIcon: const Icon(Icons.note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter dropoff note';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Optional Photo Upload
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Parcel Photo (Optional)',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Add photo to help riders',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_parcelPhoto == null)
                        ElevatedButton.icon(
                          onPressed: _pickPhoto,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Add Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF667eea),
                            side: const BorderSide(color: Color(0xFF667eea)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _parcelPhoto!,
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.black54,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _parcelPhoto = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _pickPhoto,
                              icon: const Icon(Icons.swap_horiz),
                              label: const Text('Change Photo'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.send, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Post',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParcelSizeOption(String size, String emoji, String description) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _parcelSize = size),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _parcelSize == size
                ? const Color(0xFF667eea).withOpacity(0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _parcelSize == size
                  ? const Color(0xFF667eea)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // Text(emoji, style: const TextStyle(fontSize: 24)),
              Text(
                size,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: _parcelSize == size
                      ? const Color(0xFF667eea)
                      : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = 56.0;
    final availableHeight = screenHeight - appBarHeight;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'New Delivery Request',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            // Main Content Area
            Expanded(
              child: Stack(
                children: [
                  // Full Screen Map
                  SizedBox(
                    height: availableHeight,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target:
                            _harare, // Default to Harare since no auto-current
                        zoom: 15,
                      ),
                      markers: {
                        if (_pickupPosition != null)
                          Marker(
                            markerId: const MarkerId('pickup'),
                            position: _pickupPosition!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen,
                            ),
                            infoWindow: const InfoWindow(
                              title: 'Pickup Location',
                            ),
                          ),
                        if (_dropoffPosition != null)
                          Marker(
                            markerId: const MarkerId('dropoff'),
                            position: _dropoffPosition!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed,
                            ),
                            infoWindow: const InfoWindow(
                              title: 'Dropoff Location',
                            ),
                          ),
                      },
                      polylines: {
                        if (_pickupPosition != null && _dropoffPosition != null)
                          Polyline(
                            polylineId: const PolylineId('route'),
                            points: [_pickupPosition!, _dropoffPosition!],
                            color: Colors.blue,
                            width: 3,
                          ),
                      },
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                      },
                      onTap: _handleMapTap,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      compassEnabled: true,
                      rotateGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      tiltGesturesEnabled: false,
                    ),
                  ),
                  // Location Indicator Bar (Top) - Fixed position
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: _buildLocationIndicatorBar(),
                  ),
                  // Floating Location Cards - ALWAYS VISIBLE WHEN NEEDED
                  Positioned(
                    top: 90,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        // Pickup Card - Always visible when not set or expanded
                        if (_pickupPosition == null || _isPickupExpanded)
                          _buildFloatingLocationCard(
                            title: 'Pickup Location',
                            hint: 'Where should we pick up?',
                            icon: Icons.location_on,
                            iconColor: Colors.green,
                            controller: _pickupSearchController,
                            focusNode: _pickupFocusNode,
                            isPickup: true,
                            onUseCurrentLocation: () =>
                                _useCurrentLocation(true),
                            isExpanded:
                                _isPickupExpanded || _pickupPosition == null,
                          ),
                        // Spacing between cards
                        if ((_pickupPosition == null || _isPickupExpanded) &&
                            (_dropoffPosition == null || _isDropoffExpanded))
                          const SizedBox(height: 4),
                        // Dropoff Card - Always visible when not set or expanded
                        if (_dropoffPosition == null || _isDropoffExpanded)
                          _buildFloatingLocationCard(
                            title: 'Dropoff Location',
                            hint: 'Where should we deliver to?',
                            icon: Icons.location_searching,
                            iconColor: Colors.red,
                            controller: _dropoffSearchController,
                            focusNode: _dropoffFocusNode,
                            isPickup: false,
                            onUseCurrentLocation: () =>
                                _useCurrentLocation(false),
                            isExpanded:
                                _isDropoffExpanded || _dropoffPosition == null,
                          ),
                      ],
                    ),
                  ),
                  // Mini Location Controls (Right side) - Optional, can be removed
                  _buildMiniLocationControls(),
                  // Current Location Button
                  Positioned(
                    bottom: 160,
                    right: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'current_location',
                      backgroundColor: Colors.white,
                      onPressed: _getCurrentLocationForPickup,
                      child: const Icon(Icons.my_location, color: Colors.blue),
                    ),
                  ),
                  // Next Button
                  if (_pickupPosition != null &&
                      _dropoffPosition != null &&
                      !_showDetailsForm)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showDetailsForm = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.arrow_forward, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Continue',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Details Form (Sliding up) - Only when showDetailsForm is true
            if (_showDetailsForm)
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: _buildDetailsForm(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
//old