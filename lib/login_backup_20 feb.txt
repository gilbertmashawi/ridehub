import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:riderhub/screens/rider/rider_homescreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'dart:convert';
import '../screens/customer/customer_home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  CountryCode _selectedCode = CountryCode.fromCountryCode('ZW');

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _navigateToHome(String userType) async {
    if (!mounted) return;

    Widget nextScreen = (userType == 'rider')
        ? const RiderHomeScreen()
        : const CustomerHomeScreen();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Login successful as $userType!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final String dialCode = _selectedCode.dialCode ?? '+263';
      String rawPhone = _phoneController.text.trim();

      if (rawPhone.startsWith('0')) {
        rawPhone = rawPhone.substring(1);
      }

      final String fullPhone = dialCode + rawPhone;
      debugPrint('Attempting login for phone: $fullPhone');

      setState(() => _isLoading = true);

      try {
        final response = await http
            .post(
              Uri.parse(
                'https://chareta.com/riderhub/api/api.php?action=login',
              ),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'phone': fullPhone,
                'password': _passwordController.text,
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);

          if (responseData['error'] == null) {
            // FIXED: Save BOTH session_id AND user_id
            final String sessionId = responseData['session_id']; // REAL session
            final String userId = responseData['user_id'].toString();
            final String userType = responseData['user_type'] ?? 'customer';

            final prefs = await SharedPreferences.getInstance();
            // Save BOTH session_id AND user_id
            await prefs.setString('session_id', sessionId);
            await prefs.setInt('user_id', int.parse(userId));
            await prefs.setString('user_type', userType);
            await prefs.setBool('isLoggedIn', true);

            // Profile fetch now uses sessionId (the real session)
            await _fetchAndStoreUserProfile(sessionId);

            if (mounted) {
              _navigateToHome(userType);
            }
          } else {
            _showError(responseData['error']);
          }
        } else {
          _showError('Login failed: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        _showError('Network error: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchAndStoreUserProfile(String sessionId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://chareta.com/riderhub/api/api.php?action=profile',
            ),
            headers: {'X-Session-Id': sessionId}, // Use real session
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['error'] == null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', responseData['name'] ?? '');
          await prefs.setString('user_phone', responseData['phone'] ?? '');
          await prefs.setString('user_email', responseData['email'] ?? '');
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
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Your beautiful UI — 100% unchanged
                    Container(
                      width: 140,
                      height: 140,
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
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.account_circle_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    Text(
                      'Welcome Back',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue your journey',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 48.0),

                    // Phone Field
                    Row(
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: 'Enter your phone',
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
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
                                vertical: 20,
                                horizontal: 20,
                              ),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Please enter your phone number'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.white70,
                            size: 24,
                          ),
                        ),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          child: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.white70,
                              size: 24,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        labelStyle: const TextStyle(color: Colors.white70),
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
                          vertical: 20,
                          horizontal: 20,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter your password';
                        if (value.length < 6)
                          return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8.0),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32.0),

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF667eea),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                          shadowColor: Colors.black.withOpacity(0.3),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF667eea),
                                  ),
                                ),
                              )
                            : Text(
                                'Sign In',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 28.0),

                    // Divider + Social Buttons + Sign Up Link — 100% untouched
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.white.withOpacity(0.3),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Or continue with',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.white.withOpacity(0.3),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28.0),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextButton.icon(
                              icon: Container(
                                padding: const EdgeInsets.all(2),
                                child: Icon(Icons.email_outlined),
                              ),
                              label: Text(
                                'Email',
                                style: GoogleFonts.inter(
                                  color: Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {},
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white70,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TextButton.icon(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.phone_iphone_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                              label: Text(
                                'Phone',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40.0),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          ),
                          child: Text(
                            'Sign Up',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
