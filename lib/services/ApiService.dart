// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://chareta.com/riderhub/api/api.php';

  // SharedPreferences key
  static const String _userKey = 'user_data';
  static const String _sessionKey = 'session_id';

  // Get stored user
  static Future<Map<String, dynamic>> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return jsonDecode(userJson);
    }
    return {};
  }

  // Save user
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  // Get session ID
  static Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  // Save session ID
  static Future<void> saveSessionId(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, sessionId);
  }

  // Clear session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_sessionKey);
  }

  // Get headers with session
  static Future<Map<String, String>> _getHeaders() async {
    final sessionId = await getSessionId();
    return {
      'Content-Type': 'application/json',
      'X-Session-Id': sessionId ?? '',
    };
  }

  // ========== AUTHENTICATION ==========

  static Future<Map<String, dynamic>> login(
    String phone,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['error'] == null) {
          // Save session and user
          await saveSessionId(data['session_id']);
          await saveUser({
            'id': data['user_id'],
            'user_type': data['user_type'],
          });
        }

        return data;
      } else {
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
    required String userType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'password': password,
          'user_type': userType,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> registerWithFiles({
    required String name,
    required String phone,
    required String password,
    required String userType,
    required File faceImage,
    required File idFrontImage,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl?action=register_multipart'),
      );

      // Add fields
      request.fields['name'] = name;
      request.fields['phone'] = phone;
      request.fields['password'] = password;
      request.fields['user_type'] = userType;

      // Add files
      request.files.add(
        await http.MultipartFile.fromPath(
          'face_picture',
          faceImage.path,
          filename: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'id_front_picture',
          idFrontImage.path,
          filename: 'id_front_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=logout'),
        headers: await _getHeaders(),
      );

      await clearSession();
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=profile'),
        headers: await _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  // ========== WALLET & TOP-UP ==========

  static Future<Map<String, dynamic>> getWalletBalance() async {
    try {
      final user = await getUser();
      if (user.isEmpty) throw Exception('Not logged in');

      final response = await http.get(
        Uri.parse('$baseUrl?action=get_wallet_balance'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception(data['error']);
        }
        return data;
      } else {
        throw Exception('Failed to load wallet balance');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<dynamic>> getTopUpHistory() async {
    try {
      final user = await getUser();
      if (user.isEmpty) throw Exception('Not logged in');

      final response = await http.get(
        Uri.parse('$baseUrl?action=get_topup_history'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception(data['error']);
        }
        return data['history'] ?? [];
      } else {
        throw Exception('Failed to load top-up history');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> submitTopUp({
    required double amount,
    required int validDays,
    required File imageFile,
  }) async {
    try {
      final user = await getUser();
      if (user.isEmpty) throw Exception('Not logged in');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl?action=submit_topup'),
      );

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll({'X-Session-Id': headers['X-Session-Id'] ?? ''});

      // Add fields
      request.fields['amount'] = amount.toString();
      request.fields['valid_days'] = validDays.toString();

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'proof_image',
          imageFile.path,
          filename: 'topup_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception(data['error']);
        }
        return data;
      } else {
        throw Exception('Failed to submit top-up: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ========== RIDER APPLICATIONS ==========

  static Future<Map<String, dynamic>> getRiderApplicationStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=rider_application_status'),
        headers: await _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> submitRiderApplication({
    required String fullName,
    required String idNumber,
    required String vehicleRegistration,
    required String address,
    required String emergencyContact,
    required String vehicleType,
    required String vehicleModel,
    required String vehicleYear,
    required String licenseNumber,
    required File idFrontImage,
    required File idBackImage,
    required File vehicleFrontImage,
    required File vehicleBackImage,
    required File licenseImage,
  }) async {
    try {
      final sessionId = await getSessionId();
      if (sessionId == null) throw Exception('Not logged in');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl?action=apply_rider'),
      );

      // Add headers with session
      request.headers['X-Session-Id'] = sessionId;

      // Add form fields
      request.fields['full_name'] = fullName;
      request.fields['id_number'] = idNumber;
      request.fields['vehicle_registration'] = vehicleRegistration;
      request.fields['address'] = address;
      request.fields['emergency_contact'] = emergencyContact;
      request.fields['vehicle_type'] = vehicleType;
      request.fields['vehicle_model'] = vehicleModel;
      request.fields['vehicle_year'] = vehicleYear;
      request.fields['license_number'] = licenseNumber;

      // Add image files
      request.files.add(
        await http.MultipartFile.fromPath(
          'id_front_image',
          idFrontImage.path,
          filename: 'id_front_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'id_back_image',
          idBackImage.path,
          filename: 'id_back_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'vehicle_front_image',
          vehicleFrontImage.path,
          filename:
              'vehicle_front_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'vehicle_back_image',
          vehicleBackImage.path,
          filename: 'vehicle_back_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'license_image',
          licenseImage.path,
          filename: 'license_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> clearRiderApplication() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=clear_rider_application'),
        headers: await _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  // ========== DELIVERY ORDERS ==========

  static Future<List<dynamic>> getNearbyDeliveryOrders({
    required double lat,
    required double lng,
    double radius = 50.0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl?action=requests_nearby&lat=$lat&lng=$lng&radius=$radius',
        ),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception(data['error']);
        }
        return data['requests'] ?? [];
      } else {
        throw Exception('Failed to load nearby orders');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createDeliveryOrder({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required String parcelSize,
    required double suggestedFare,
    required String paymentMethod,
    File? parcelPhoto,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl?action=requests'),
      );

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll({'X-Session-Id': headers['X-Session-Id'] ?? ''});

      // Add fields
      request.fields['pickup_lat'] = pickupLat.toString();
      request.fields['pickup_lng'] = pickupLng.toString();
      request.fields['dropoff_lat'] = dropoffLat.toString();
      request.fields['dropoff_lng'] = dropoffLng.toString();
      request.fields['parcel_size'] = parcelSize;
      request.fields['suggested_fare'] = suggestedFare.toString();
      request.fields['payment_method'] = paymentMethod;

      // Add photo if provided
      if (parcelPhoto != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'parcel_photo',
            parcelPhoto.path,
            filename: 'parcel_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> acceptJob({
    required int deliveryOrderId,
    double fare = 0.0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=accept_job'),
        headers: await _getHeaders(),
        body: jsonEncode({'delivery_order_id': deliveryOrderId, 'fare': fare}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getActiveAssignment() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get_active_assignment'),
        headers: await _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getActiveCustomerDelivery() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get_active_customer_delivery'),
        headers: await _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  // ========== CHAT ==========

  static Future<Map<String, dynamic>> sendMessage({
    required int deliveryId,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=send_message'),
        headers: await _getHeaders(),
        body: jsonEncode({'delivery_id': deliveryId, 'message': message}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getMessages(int deliveryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get_messages&delivery_id=$deliveryId'),
        headers: await _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  // ========== LOCATION ==========

  static Future<Map<String, dynamic>> updateDeliveryLocation({
    required int deliveryId,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=update_delivery_location'),
        headers: await _getHeaders(),
        body: jsonEncode({'delivery_id': deliveryId, 'lat': lat, 'lng': lng}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getDeliveryLocation(
    int deliveryId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl?action=get_delivery_location&delivery_id=$deliveryId',
        ),
        headers: await _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  // ========== NOTIFICATIONS ==========

  static Future<List<dynamic>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=notifications'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['notifications'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<int> getUnreadNotificationCount() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get_unread_notification_count'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unread_count'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<Map<String, dynamic>> markNotificationRead(
    int notificationId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=mark_notification_read'),
        headers: await _getHeaders(),
        body: jsonEncode({'notification_id': notificationId}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  // ========== SYSTEM SETTINGS ==========

  static Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get_system_settings'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['settings'] ?? {};
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // ========== OTP ==========

  static Future<Map<String, dynamic>> sendOTP(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=send_otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> verifyOTP(
    String phone,
    String otp,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=verify_otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otp': otp}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  // ========== EMAIL AUTH ==========

  static Future<Map<String, dynamic>> sendEmailOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=send_email_otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> verifyEmailOTP(
    String email,
    String otp,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=verify_email_otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> registerWithEmail({
    required String email,
    required String name,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=register_email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'name': name,
          'phone': phone,
          'password': password,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  // ========== BIDS ==========

  static Future<Map<String, dynamic>> submitBid({
    required int deliveryOrderId,
    required double bidAmount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=submit_bid'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'delivery_order_id': deliveryOrderId,
          'bid_amount': bidAmount,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getBids({int? deliveryOrderId}) async {
    try {
      String url = '$baseUrl?action=get_bids';
      if (deliveryOrderId != null) {
        url += '&delivery_order_id=$deliveryOrderId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> acceptBid(int bidId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=accept_bid'),
        headers: await _getHeaders(),
        body: jsonEncode({'bid_id': bidId}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  // ========== SESSION ==========

  static Future<Map<String, dynamic>> checkSession() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=check_session'),
        headers: await _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Session check failed'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=update_profile'),
        headers: await _getHeaders(),
        body: jsonEncode({'name': name, 'phone': phone}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }
}
