// lib/screens/signup_screen.dart
import 'dart:async';

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
// PHONE ENTRY SCREEN — now styled like LoginScreen
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

  @override
  void initState() {
    super.initState();
    _detectSimNumber();
  }

  Future<void> _detectSimNumber() async {
    // Keeping your existing logic (can be improved later with real telephony if needed)
    setState(() => _isDetecting = true);
    try {
      // ... permission logic ...
      setState(() {
        _selectedCode = CountryCode(
          dialCode: '+263',
          code: 'ZW',
          name: 'Zimbabwe',
        );
      });
    } catch (e) {
      debugPrint('Phone detection failed: $e');
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  Future<void> _showConfirmNumberDialog() async {
    final String rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      _showError('Please enter phone number first');
      return;
    }

    final String displayNumber = '${_selectedCode.dialCode}$rawPhone';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Phone',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Is this your correct number?',
              style: GoogleFonts.inter(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                displayNumber,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF667eea),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false), // Edit → close dialog
            child: Text(
              'Edit',
              style: GoogleFonts.inter(color: Colors.grey.shade700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Yes → proceed
            child: Text(
              'Yes',
              style: GoogleFonts.inter(
                color: const Color(0xFF667eea),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _sendOtp();
    }
  }

  Future<void> _sendOtp() async {
    final String rawPhone = _phoneController.text.trim();

    if (rawPhone.isEmpty) {
      _showError('Phone number is required');
      return;
    }

    // Basic Zimbabwe format check (can be stricter if needed)
    if (!RegExp(r'^(07|08)\d{8}$').hasMatch(rawPhone)) {
      _showError('Please use a valid Zimbabwe number (e.g. 0771234567)');
      return;
    }

    final String fullPhone = '${_selectedCode.dialCode}$rawPhone';

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

      if (response.statusCode == 200 && data['error'] == null) {
        if (data['dev_otp'] != null) {
          await NotificationService.showOtpNotification(
            data['dev_otp'].toString(),
          );
        }

        if (mounted) {
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
        _showError(data['error'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      _showError('Network error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo – same style as Login
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 25,
                          offset: const Offset(0, 15),
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.delivery_dining_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Get Started',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Enter your phone number to continue',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Phone input field – matched style
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CountryCodePicker(
                        onChanged: (code) =>
                            setState(() => _selectedCode = code),
                        initialSelection: 'ZW',
                        favorite: const ['+263', 'ZW'],
                        showCountryOnly: false,
                        alignLeft: false,
                        textStyle: GoogleFonts.inter(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        dialogBackgroundColor: Colors.white,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        boxDecoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          cursorColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                          ),
                          decoration: InputDecoration(
                            hintText: '0771 234 567',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.white54,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_isDetecting) ...[
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: Colors.white70),
                    const SizedBox(height: 12),
                    Text(
                      'Checking device info...',
                      style: GoogleFonts.inter(color: Colors.white70),
                    ),
                  ],

                  const SizedBox(height: 48),

                  // Send OTP Button
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isSending || _isDetecting
                          ? null
                          : _showConfirmNumberDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF667eea),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                        shadowColor: Colors.black.withOpacity(0.3),
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF667eea),
                                ),
                              ),
                            )
                          : Text(
                              'Send ',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "I have an account? ",
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        ),
                        child: Text(
                          'Log In',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// OTP VERIFY SCREEN
// // ===================================================================
// class OtpVerifyScreen extends StatefulWidget {
//   final String phone;
//   const OtpVerifyScreen({super.key, required this.phone});
//   @override
//   State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
// }

// bool _isResending = false;
// int _resendCooldown = 0;

// class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
//   final TextEditingController _otpController = TextEditingController();
//   bool _isVerifying = false;

//   @override
//   void dispose() {
//     _otpController.dispose();
//     super.dispose();
//   }

//   Future<void> _verifyOtp() async {
//     final String otp = _otpController.text.trim();

//     if (otp.isEmpty || otp.length != 6) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please enter 6-digit OTP'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }

//     setState(() => _isVerifying = true);

//     try {
//       final response = await http
//           .post(
//             Uri.parse('$_baseUrl?action=verify_otp'),
//             headers: {'Content-Type': 'application/json'},
//             body: jsonEncode({'phone': widget.phone, 'otp': otp}),
//           )
//           .timeout(const Duration(seconds: 30));

//       final data = jsonDecode(response.body);
//       debugPrint('Verify OTP Response: $data');

//       if (response.statusCode == 200) {
//         if (data['verified'] == true) {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (_) => RegisterDetailsScreen(phone: widget.phone),
//             ),
//           );
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(data['error'] ?? 'Invalid OTP'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Verification failed: ${response.statusCode}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Network error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() => _isVerifying = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Verify OTP'),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         foregroundColor: Colors.black87,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             const SizedBox(height: 40),
//             Text(
//               'Enter 6-digit code sent to',
//               textAlign: TextAlign.center,
//               style: GoogleFonts.inter(fontSize: 18),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               widget.phone,
//               textAlign: TextAlign.center,
//               style: GoogleFonts.inter(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: const Color(0xFF667eea),
//               ),
//             ),
//             const SizedBox(height: 40),
//             TextField(
//               controller: _otpController,
//               keyboardType: TextInputType.number,
//               textAlign: TextAlign.center,
//               maxLength: 6,
//               style: GoogleFonts.inter(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//               decoration: InputDecoration(
//                 counterText: '',
//                 filled: true,
//                 fillColor: Colors.grey.shade50,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide.none,
//                 ),
//                 hintText: '123456',
//                 hintStyle: GoogleFonts.inter(fontSize: 18, color: Colors.grey),
//               ),
//             ),
//             const SizedBox(height: 30),
//             SizedBox(
//               height: 56,
//               child: ElevatedButton(
//                 onPressed: _isVerifying ? null : _verifyOtp,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF667eea),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 child: _isVerifying
//                     ? const CircularProgressIndicator(color: Colors.white)
//                     : Text(
//                         'Verify OTP',
//                         style: GoogleFonts.inter(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//               ),
//             ),
//             const SizedBox(height: 20),
//             TextButton(
//               onPressed: _isVerifying || _isResending || _resendCooldown > 0
//                   ? null
//                   : () async {
//                       setState(() {
//                         _isResending = true;
//                       });

//                       try {
//                         final response = await http
//                             .post(
//                               Uri.parse('$_baseUrl?action=send_otp'),
//                               headers: {'Content-Type': 'application/json'},
//                               body: jsonEncode({'phone': widget.phone}),
//                             )
//                             .timeout(const Duration(seconds: 30));

//                         final data = jsonDecode(response.body);

//                         if (response.statusCode == 200 &&
//                             data['error'] == null) {
//                           // Optional: Show dev OTP in notification (if backend returns it)
//                           if (data['dev_otp'] != null) {
//                             await NotificationService.showOtpNotification(
//                               data['dev_otp'].toString(),
//                             );
//                           }

//                           if (mounted) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                 content: Text(
//                                   'New OTP sent! Check your phone.',
//                                 ),
//                                 backgroundColor: Colors.green,
//                               ),
//                             );

//                             // Start 60-second cooldown
//                             setState(() {
//                               _resendCooldown = 60;
//                             });

//                             // Countdown timer
//                             Timer.periodic(const Duration(seconds: 1), (timer) {
//                               if (_resendCooldown > 0 && mounted) {
//                                 setState(() => _resendCooldown--);
//                               } else {
//                                 timer.cancel();
//                               }
//                             });
//                           }
//                         } else {
//                           if (mounted) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               SnackBar(
//                                 content: Text(
//                                   data['error'] ?? 'Failed to resend OTP',
//                                 ),
//                                 backgroundColor: Colors.red,
//                               ),
//                             );
//                           }
//                         }
//                       } catch (e) {
//                         if (mounted) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text('Network error: $e'),
//                               backgroundColor: Colors.red,
//                             ),
//                           );
//                         }
//                       } finally {
//                         if (mounted) {
//                           setState(() {
//                             _isResending = false;
//                           });
//                         }
//                       }
//                     },
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   if (_isResending)
//                     const Padding(
//                       padding: EdgeInsets.only(right: 8),
//                       child: SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2.5,
//                           valueColor: AlwaysStoppedAnimation<Color>(
//                             Color(0xFF667eea),
//                           ),
//                         ),
//                       ),
//                     ),
//                   Text(
//                     _resendCooldown > 0
//                         ? 'Resend in $_resendCooldown s'
//                         : "Didn't receive code? Resend",
//                     style: GoogleFonts.inter(
//                       color: _resendCooldown > 0 || _isResending
//                           ? Colors.grey.shade500
//                           : const Color(0xFF667eea),
//                       fontWeight: _resendCooldown > 0 || _isResending
//                           ? FontWeight.normal
//                           : FontWeight.w600,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// ===================================================================
// OTP VERIFY SCREEN — now consistent with LoginScreen & PhoneEntryScreen
// ===================================================================
class OtpVerifyScreen extends StatefulWidget {
  final String phone;
  const OtpVerifyScreen({super.key, required this.phone});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

bool _isResending = false;
int _resendCooldown = 0;

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo — matching LoginScreen & PhoneEntryScreen
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 25,
                          offset: const Offset(0, 15),
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.delivery_dining_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Verify Your Number',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Enter the 6-digit code sent to',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    widget.phone,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // OTP input — styled like other auth fields
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 12.0,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '—— ——',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 32,
                        color: Colors.white38,
                        letterSpacing: 12.0,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.13),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.white54,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Verify button — white bg + brand color text, like login
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF667eea),
                        elevation: 5,
                        shadowColor: Colors.black.withOpacity(0.25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF667eea),
                                ),
                              ),
                            )
                          : Text(
                              'Verify & Continue',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Resend button — white text, subtle when disabled/cooldown
                  TextButton(
                    onPressed:
                        _isVerifying || _isResending || _resendCooldown > 0
                        ? null
                        : () async {
                            setState(() {
                              _isResending = true;
                            });

                            try {
                              final response = await http
                                  .post(
                                    Uri.parse('$_baseUrl?action=send_otp'),
                                    headers: {
                                      'Content-Type': 'application/json',
                                    },
                                    body: jsonEncode({'phone': widget.phone}),
                                  )
                                  .timeout(const Duration(seconds: 30));

                              final data = jsonDecode(response.body);

                              if (response.statusCode == 200 &&
                                  data['error'] == null) {
                                if (data['dev_otp'] != null) {
                                  await NotificationService.showOtpNotification(
                                    data['dev_otp'].toString(),
                                  );
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'New OTP sent! Check your phone.',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );

                                  setState(() {
                                    _resendCooldown = 60;
                                  });

                                  Timer.periodic(const Duration(seconds: 1), (
                                    timer,
                                  ) {
                                    if (_resendCooldown > 0 && mounted) {
                                      setState(() => _resendCooldown--);
                                    } else {
                                      timer.cancel();
                                    }
                                  });
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        data['error'] ?? 'Failed to resend OTP',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Network error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isResending = false;
                                });
                              }
                            }
                          },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isResending)
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        Text(
                          _resendCooldown > 0
                              ? 'Resend in $_resendCooldown s'
                              : "Didn't receive the code? Resend",
                          style: GoogleFonts.inter(
                            color: _resendCooldown > 0 || _isResending
                                ? Colors.white60
                                : Colors.white,
                            fontSize: 15,
                            fontWeight: _resendCooldown > 0 || _isResending
                                ? FontWeight.normal
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// REGISTRATION DETAILS SCREEN
// ===================================================================
// class RegisterDetailsScreen extends StatefulWidget {
//   final String phone;
//   const RegisterDetailsScreen({super.key, required this.phone});

//   @override
//   State<RegisterDetailsScreen> createState() => _RegisterDetailsScreenState();
// }

// class _RegisterDetailsScreenState extends State<RegisterDetailsScreen> {
//   final TextEditingController _firstNameController = TextEditingController();
//   final TextEditingController _lastNameController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();

//   File? _facePicture;
//   File? _idFrontPicture;

//   bool _isRegistering = false;
//   final ImagePicker _picker = ImagePicker();

//   @override
//   void dispose() {
//     _firstNameController.dispose();
//     _lastNameController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   Future<void> _pickImage(ImageSource source, bool isFacePicture) async {
//     try {
//       final pickedFile = await _picker.pickImage(
//         source: source,
//         imageQuality: 80,
//         maxWidth: 800,
//         maxHeight: 800,
//       );

//       if (pickedFile != null) {
//         setState(() {
//           if (isFacePicture) {
//             _facePicture = File(pickedFile.path);
//           } else {
//             _idFrontPicture = File(pickedFile.path);
//           }
//         });
//       }
//     } catch (e) {
//       debugPrint('Image pick error: $e');
//       _showError('Failed to pick image: $e');
//     }
//   }

//   Widget _buildImagePicker({
//     required String title,
//     required String buttonText,
//     required File? imageFile,
//     required bool isFacePicture,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           title,
//           style: GoogleFonts.inter(
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//             color: Colors.black87,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Container(
//           height: 140,
//           decoration: BoxDecoration(
//             color: Colors.grey.shade50,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.grey.shade300),
//           ),
//           child: imageFile == null
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       OutlinedButton.icon(
//                         onPressed: _isRegistering
//                             ? null
//                             : () async {
//                                 await _pickImage(
//                                   ImageSource.gallery,
//                                   isFacePicture,
//                                 );
//                               },
//                         icon: const Icon(Icons.photo_library),
//                         label: Text('$buttonText from Gallery'),
//                       ),
//                       const SizedBox(height: 8),
//                       OutlinedButton.icon(
//                         onPressed: _isRegistering
//                             ? null
//                             : () async {
//                                 await _pickImage(
//                                   ImageSource.camera,
//                                   isFacePicture,
//                                 );
//                               },
//                         icon: const Icon(Icons.camera_alt),
//                         label: Text('$buttonText with Camera'),
//                       ),
//                     ],
//                   ),
//                 )
//               : Stack(
//                   fit: StackFit.expand,
//                   children: [
//                     ClipRRect(
//                       borderRadius: BorderRadius.circular(12),
//                       child: Image.file(imageFile, fit: BoxFit.cover),
//                     ),
//                     Positioned(
//                       top: 8,
//                       right: 8,
//                       child: GestureDetector(
//                         onTap: () {
//                           setState(() {
//                             if (isFacePicture) {
//                               _facePicture = null;
//                             } else {
//                               _idFrontPicture = null;
//                             }
//                           });
//                         },
//                         child: CircleAvatar(
//                           backgroundColor: Colors.red.withOpacity(0.8),
//                           radius: 14,
//                           child: const Icon(
//                             Icons.close,
//                             size: 16,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//         ),
//         const SizedBox(height: 16),
//       ],
//     );
//   }

//   Future<void> _registerUser() async {
//     final String firstName = _firstNameController.text.trim();
//     final String lastName = _lastNameController.text.trim();
//     final String password = _passwordController.text.trim();

//     // Validation — removed image checks
//     if (firstName.isEmpty || lastName.isEmpty) {
//       _showError('Please enter your first and last name');
//       return;
//     }

//     if (password.isEmpty || password.length < 6) {
//       _showError('Password must be at least 6 characters');
//       return;
//     }

//     final String fullName = '$firstName $lastName';
//     setState(() => _isRegistering = true);

//     try {
//       // Create multipart request
//       var request = http.MultipartRequest(
//         'POST',
//         Uri.parse('$_baseUrl?action=register_multipart'),
//       );

//       // Add text fields
//       request.fields['name'] = fullName;
//       request.fields['phone'] = widget.phone;
//       request.fields['password'] = password;
//       request.fields['user_type'] = 'customer';

//       // Add images ONLY if they exist (optional now)
//       if (_facePicture != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'face_picture',
//             _facePicture!.path,
//             filename: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
//           ),
//         );
//       }

//       if (_idFrontPicture != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'id_front_picture',
//             _idFrontPicture!.path,
//             filename: 'id_${DateTime.now().millisecondsSinceEpoch}.jpg',
//           ),
//         );
//       }

//       // Send request
//       final streamedResponse = await request.send();
//       final response = await http.Response.fromStream(streamedResponse);

//       debugPrint('Registration status: ${response.statusCode}');
//       debugPrint('Registration body: ${response.body}');

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         final responseData = jsonDecode(response.body);

//         if (responseData['error'] != null) {
//           _showError(responseData['error']);
//           return;
//         }

//         // Save session data
//         final String sessionId = responseData['session_id'];
//         final String userId = responseData['user_id'].toString();
//         final String userType = responseData['user_type'] ?? 'customer';

//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString('session_id', sessionId);
//         await prefs.setInt('user_id', int.parse(userId));
//         await prefs.setString('user_type', userType);
//         await prefs.setBool('isLoggedIn', true);

//         // Fetch and store profile
//         await _fetchAndStoreUserProfile(sessionId);

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Registration successful!'),
//               backgroundColor: Colors.green,
//               behavior: SnackBarBehavior.floating,
//             ),
//           );

//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
//           );
//         }
//       } else {
//         final errorData = jsonDecode(response.body);
//         _showError(errorData['error'] ?? 'Registration failed');
//       }
//     } catch (e) {
//       debugPrint('Registration error: $e');
//       _showError('Network error: $e');
//     } finally {
//       if (mounted) setState(() => _isRegistering = false);
//     }
//   }

//   Future<void> _fetchAndStoreUserProfile(String sessionId) async {
//     try {
//       final response = await http
//           .get(
//             Uri.parse('$_baseUrl?action=profile'),
//             headers: {'X-Session-Id': sessionId},
//           )
//           .timeout(const Duration(seconds: 30));

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         if (data['error'] == null) {
//           final prefs = await SharedPreferences.getInstance();
//           await prefs.setString('user_name', data['name'] ?? '');
//           await prefs.setString('user_phone', data['phone'] ?? '');
//         }
//       }
//     } catch (e) {
//       debugPrint('Profile fetch error: $e');
//     }
//   }

//   void _showError(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(message),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: Text(
//           'Complete Registration',
//           style: GoogleFonts.inter(fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         foregroundColor: Colors.black87,
//         centerTitle: true,
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(24.0),
//           child: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 const SizedBox(height: 20),
//                 Text(
//                   'Your phone ${widget.phone} is verified.',
//                   style: GoogleFonts.inter(
//                     fontSize: 16,
//                     color: Colors.grey.shade600,
//                   ),
//                 ),
//                 const SizedBox(height: 32),

//                 // Text Fields
//                 TextFormField(
//                   controller: _firstNameController,
//                   decoration: _buildInputDecoration('First Name'),
//                   style: GoogleFonts.inter(color: Colors.black87),
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: _lastNameController,
//                   decoration: _buildInputDecoration('Last Name'),
//                   style: GoogleFonts.inter(color: Colors.black87),
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   controller: _passwordController,
//                   obscureText: true,
//                   decoration: _buildInputDecoration(
//                     'Password (min 6 characters)',
//                   ),
//                   style: GoogleFonts.inter(color: Colors.black87),
//                 ),
//                 const SizedBox(height: 32),

//                 // // Face Picture Upload (optional)
//                 // _buildImagePicker(
//                 //   title: 'Face Picture (optional)',
//                 //   buttonText: 'Select Face Picture',
//                 //   imageFile: _facePicture,
//                 //   isFacePicture: true,
//                 // ),

//                 // const SizedBox(height: 24),

//                 // // ID Front Picture Upload (optional)
//                 // _buildImagePicker(
//                 //   title: 'ID/License Front Picture (optional)',
//                 //   buttonText: 'Select ID Picture',
//                 //   imageFile: _idFrontPicture,
//                 //   isFacePicture: false,
//                 // ),
//                 const SizedBox(height: 32),

//                 // Register Button
//                 SizedBox(
//                   height: 56,
//                   child: ElevatedButton(
//                     onPressed: _isRegistering ? null : _registerUser,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color(0xFF667eea),
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       elevation: 4,
//                     ),
//                     child: _isRegistering
//                         ? const SizedBox(
//                             height: 20,
//                             width: 20,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               valueColor: AlwaysStoppedAnimation<Color>(
//                                 Colors.white,
//                               ),
//                             ),
//                           )
//                         : Text(
//                             'Complete Registration',
//                             style: GoogleFonts.inter(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                   ),
//                 ),
//                 const SizedBox(height: 32),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   InputDecoration _buildInputDecoration(String label) {
//     return InputDecoration(
//       labelText: label,
//       labelStyle: TextStyle(color: Colors.grey.shade600),
//       filled: true,
//       fillColor: Colors.grey.shade50,
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: BorderSide(color: Colors.grey.shade300),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: BorderSide(color: Colors.grey.shade300),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
//       ),
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//     );
//   }
// }

// ===================================================================
// REGISTRATION DETAILS SCREEN — now consistent with other auth screens
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
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
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
                        icon: const Icon(
                          Icons.photo_library,
                          color: Colors.white70,
                        ),
                        label: Text(
                          '$buttonText from Gallery',
                          style: GoogleFonts.inter(color: Colors.white70),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isRegistering
                            ? null
                            : () async {
                                await _pickImage(
                                  ImageSource.camera,
                                  isFacePicture,
                                );
                              },
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.white70,
                        ),
                        label: Text(
                          '$buttonText with Camera',
                          style: GoogleFonts.inter(color: Colors.white70),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(imageFile, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isFacePicture)
                              _facePicture = null;
                            else
                              _idFrontPicture = null;
                          });
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.red.withOpacity(0.9),
                          radius: 16,
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _registerUser() async {
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String password = _passwordController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      _showError('Please enter your first and last name');
      return;
    }

    if (password.isEmpty || password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    final String fullName = '$firstName $lastName';
    setState(() => _isRegistering = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl?action=register_multipart'),
      );

      request.fields['name'] = fullName;
      request.fields['phone'] = widget.phone;
      request.fields['password'] = password;
      request.fields['user_type'] = 'customer';

      if (_facePicture != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'face_picture',
            _facePicture!.path,
            filename: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }

      if (_idFrontPicture != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'id_front_picture',
            _idFrontPicture!.path,
            filename: 'id_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );
      }

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

        final String sessionId = responseData['session_id'];
        final String userId = responseData['user_id'].toString();
        final String userType = responseData['user_type'] ?? 'customer';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_id', sessionId);
        await prefs.setInt('user_id', int.parse(userId));
        await prefs.setString('user_type', userType);
        await prefs.setBool('isLoggedIn', true);

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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo — consistent with previous screens
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 25,
                          offset: const Offset(0, 15),
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.delivery_dining_rounded,
                              size: 55,
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Complete Your Profile',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Phone verified: ${widget.phone}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // First Name
                  TextFormField(
                    controller: _firstNameController,
                    decoration: _buildInputDecoration('First Name'),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),

                  const SizedBox(height: 20),

                  // Last Name
                  TextFormField(
                    controller: _lastNameController,
                    decoration: _buildInputDecoration('Last Name'),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),

                  const SizedBox(height: 20),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: _buildInputDecoration('Password (min 6 chars)'),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),

                  const SizedBox(height: 40),

                  // Uncomment these blocks if/when you want to re-enable image uploads
                  /*
                  _buildImagePicker(
                    title: 'Face Picture (optional)',
                    buttonText: 'Face Photo',
                    imageFile: _facePicture,
                    isFacePicture: true,
                  ),
                  const SizedBox(height: 24),
                  _buildImagePicker(
                    title: 'ID / License Front (optional)',
                    buttonText: 'ID Photo',
                    imageFile: _idFrontPicture,
                    isFacePicture: false,
                  ),
                  const SizedBox(height: 32),
                  */

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isRegistering ? null : _registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF667eea),
                        elevation: 6,
                        shadowColor: Colors.black.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isRegistering
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF667eea),
                                ),
                              ),
                            )
                          : Text(
                              'Create Account',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white70, fontSize: 15),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white54, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }
}
