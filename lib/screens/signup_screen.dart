// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:riderhub/screens/signup_email_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riderhub/services/notification_service.dart';
import 'package:riderhub/screens/login.dart';
import 'package:riderhub/screens/customer/customer_home_screen.dart';

const String _baseUrl = 'https://chareta.com/riderhub/api/api.php';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isLoading = false;

  Future<void> _fetchAndStoreUserProfile(String sessionId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl?action=profile'),
            headers: {'X-Session-Id': sessionId},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] == null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', data['name'] ?? '');
          await prefs.setString('user_phone', data['phone'] ?? '');
          await prefs.setString('user_email', data['email'] ?? '');
        }
      }
    } catch (e) {
      debugPrint('Profile fetch error: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Create Your Account',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Join RiderHub today',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 60),

              // PHONE BUTTON
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PhoneEntryScreen(),
                          ),
                        ),
                  icon: const Icon(Icons.phone_rounded, color: Colors.white),
                  label: Text(
                    'Continue with Phone',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),

              // EMAIL BUTTON
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const SignUpWithEmailScreen(),
                            ),
                          );
                        },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF4285F4),
                      size: 20,
                    ),
                  ),
                  label: Text(
                    'Continue with Email',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF667eea)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: GoogleFonts.inter(color: Colors.grey.shade600),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: Text(
                      'Sign In',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF667eea),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// PHONE ENTRY SCREEN
// ===================================================================
class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});
  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final TextEditingController _phoneController = TextEditingController();
  CountryCode _selectedCode = CountryCode.fromCountryCode('ZW');
  bool _isSending = false;
  bool _isDetecting = false;
  String? _devicePhone;

  @override
  void initState() {
    super.initState();
    _detectSimNumber();
  }

  Future<void> _detectSimNumber() async {
    setState(() => _isDetecting = true);

    try {
      // Try to get phone permission
      var status = await Permission.phone.status;
      if (!status.isGranted) {
        status = await Permission.phone.request();
      }

      if (status.isGranted) {
        // For simplicity, we'll use a manual approach
        // In production, you might need to use platform channels
        // or a different package for phone number detection
        debugPrint('Phone permission granted');

        // Set default Zimbabwe code
        setState(() {
          _selectedCode = CountryCode(
            dialCode: '+263',
            code: 'ZW',
            name: 'Zimbabwe',
          );
        });
      }
    } catch (e) {
      debugPrint('Phone detection failed: $e');
    } finally {
      setState(() => _isDetecting = false);
    }
  }

  Future<void> _sendOtp() async {
    final String phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      _showError('Phone number is required');
      return;
    }

    // Validate Zimbabwean phone number format
    if (!RegExp(r'^(07|08)\d{8}$').hasMatch(phoneNumber)) {
      _showError(
        'Please enter a valid Zimbabwean phone number starting with 07 or 08',
      );
      return;
    }

    final String fullPhone = '+263${phoneNumber.substring(1)}';

    setState(() => _isSending = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl?action=send_otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': fullPhone}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      debugPrint('OTP Response: $data');

      if (response.statusCode == 200) {
        if (data['error'] != null) {
          _showError(data['error']);
        } else {
          // Show OTP in notification if available
          if (data['dev_otp'] != null) {
            await NotificationService.showOtpNotification(
              data['dev_otp'].toString(),
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerifyScreen(phone: fullPhone),
            ),
          );
        }
      } else {
        _showError('Failed to send OTP: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Network error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Phone Number',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'Enter Your Phone Number',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We'll send a verification code to this number",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 40),

              Row(
                children: [
                  CountryCodePicker(
                    onChanged: (code) {
                      setState(() {
                        _selectedCode = code;
                      });
                    },
                    initialSelection: 'ZW',
                    favorite: ['+263'],
                    showCountryOnly: false,
                    showOnlyCountryWhenClosed: false,
                    alignLeft: false,
                    textStyle: GoogleFonts.inter(fontSize: 18),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: '771234567',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF667eea),
                            width: 2,
                          ),
                        ),
                      ),
                      style: GoogleFonts.inter(fontSize: 18),
                    ),
                  ),
                ],
              ),

              if (_isDetecting) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 10),
                Text(
                  'Checking permissions...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ],

              const Spacer(),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSending || _isDetecting ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Send OTP',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// OTP VERIFY SCREEN
// ===================================================================
class OtpVerifyScreen extends StatefulWidget {
  final String phone;
  const OtpVerifyScreen({super.key, required this.phone});
  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final String otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter 6-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl?action=verify_otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': widget.phone, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      debugPrint('Verify OTP Response: $data');

      if (response.statusCode == 200) {
        if (data['verified'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RegisterDetailsScreen(phone: widget.phone),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Invalid OTP'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Text(
              'Enter 6-digit code sent to',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              widget.phone,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF667eea),
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: '123456',
                hintStyle: GoogleFonts.inter(fontSize: 18, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isVerifying
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Verify OTP',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _isVerifying
                  ? null
                  : () {
                      // Option to resend OTP
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('OTP resend feature to be implemented'),
                        ),
                      );
                    },
              child: Text(
                "Didn't receive code? Resend",
                style: GoogleFonts.inter(color: const Color(0xFF667eea)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// REGISTRATION DETAILS SCREEN
// ===================================================================
class RegisterDetailsScreen extends StatefulWidget {
  final String phone;
  const RegisterDetailsScreen({super.key, required this.phone});

  @override
  State<RegisterDetailsScreen> createState() => _RegisterDetailsScreenState();
}

class _RegisterDetailsScreenState extends State<RegisterDetailsScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  File? _facePicture;
  File? _idFrontPicture;

  bool _isRegistering = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, bool isFacePicture) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        setState(() {
          if (isFacePicture) {
            _facePicture = File(pickedFile.path);
          } else {
            _idFrontPicture = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      _showError('Failed to pick image: $e');
    }
  }

  Widget _buildImagePicker({
    required String title,
    required String buttonText,
    required File? imageFile,
    required bool isFacePicture,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: imageFile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isRegistering
                            ? null
                            : () async {
                                await _pickImage(
                                  ImageSource.gallery,
                                  isFacePicture,
                                );
                              },
                        icon: const Icon(Icons.photo_library),
                        label: Text('$buttonText from Gallery'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isRegistering
                            ? null
                            : () async {
                                await _pickImage(
                                  ImageSource.camera,
                                  isFacePicture,
                                );
                              },
                        icon: const Icon(Icons.camera_alt),
                        label: Text('$buttonText with Camera'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(imageFile, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isFacePicture) {
                              _facePicture = null;
                            } else {
                              _idFrontPicture = null;
                            }
                          });
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.red.withOpacity(0.8),
                          radius: 14,
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _registerUser() async {
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String password = _passwordController.text.trim();

    // Validation
    if (firstName.isEmpty || lastName.isEmpty) {
      _showError('Please enter your first and last name');
      return;
    }

    if (password.isEmpty || password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (_facePicture == null) {
      _showError('Please upload your face picture');
      return;
    }

    if (_idFrontPicture == null) {
      _showError('Please upload your ID front picture');
      return;
    }

    final String fullName = '$firstName $lastName';
    setState(() => _isRegistering = true);

    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl?action=register_multipart'),
      );

      // Add text fields
      request.fields['name'] = fullName;
      request.fields['phone'] = widget.phone;
      request.fields['password'] = password;
      request.fields['user_type'] = 'customer';

      // Add image files
      request.files.add(
        await http.MultipartFile.fromPath(
          'face_picture',
          _facePicture!.path,
          filename: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'id_front_picture',
          _idFrontPicture!.path,
          filename: 'id_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Registration status: ${response.statusCode}');
      debugPrint('Registration body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        if (responseData['error'] != null) {
          _showError(responseData['error']);
          return;
        }

        // Save session data
        final String sessionId = responseData['session_id'];
        final String userId = responseData['user_id'].toString();
        final String userType = responseData['user_type'] ?? 'customer';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_id', sessionId);
        await prefs.setInt('user_id', int.parse(userId));
        await prefs.setString('user_type', userType);
        await prefs.setBool('isLoggedIn', true);

        // Fetch and store profile
        await _fetchAndStoreUserProfile(sessionId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showError(errorData['error'] ?? 'Registration failed');
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      _showError('Network error: $e');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _fetchAndStoreUserProfile(String sessionId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl?action=profile'),
            headers: {'X-Session-Id': sessionId},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] == null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', data['name'] ?? '');
          await prefs.setString('user_phone', data['phone'] ?? '');
        }
      }
    } catch (e) {
      debugPrint('Profile fetch error: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Complete Registration',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Complete Your Profile',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your phone ${widget.phone} is verified.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),

                // Text Fields
                TextFormField(
                  controller: _firstNameController,
                  decoration: _buildInputDecoration('First Name'),
                  style: GoogleFonts.inter(color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: _buildInputDecoration('Last Name'),
                  style: GoogleFonts.inter(color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _buildInputDecoration(
                    'Password (min 6 characters)',
                  ),
                  style: GoogleFonts.inter(color: Colors.black87),
                ),
                const SizedBox(height: 32),

                // Face Picture Upload
                _buildImagePicker(
                  title: 'Face Picture *',
                  buttonText: 'Select Face Picture',
                  imageFile: _facePicture,
                  isFacePicture: true,
                ),

                // ID Front Picture Upload
                _buildImagePicker(
                  title: 'ID/License Front Picture *',
                  buttonText: 'Select ID Picture',
                  imageFile: _idFrontPicture,
                  isFacePicture: false,
                ),

                const SizedBox(height: 32),

                // Register Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isRegistering ? null : _registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isRegistering
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Complete Registration',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
