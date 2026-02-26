// lib/screens/customer/customer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riderhub/screens/customer/TrackDeliveryWrapperScreen.dart';
import 'package:riderhub/screens/notification_popup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:riderhub/screens/customer/send_request_screen.dart';
import 'package:riderhub/screens/customer/track_delivery_screen.dart';
import 'package:riderhub/screens/customer/delivery_history_screen.dart';
import 'package:riderhub/screens/customer/notifications_screen.dart';
import 'package:riderhub/screens/customer/settings_screen.dart';
import 'package:riderhub/screens/customer/apply_rider_screen.dart';
import 'package:riderhub/screens/rider/rider_status_screen.dart';
import 'package:riderhub/screens/login.dart';
import 'customer_messages.dart';

// Add these imports for notification features
import 'package:riderhub/services/notification_stream_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;

  String _userName = 'User';
  String _userPhone = '';
  String _userType = 'customer';
  bool _isLoading = true;
  Map<String, dynamic>? _applicationData;

  // Add notification variables
  int _notificationCount = 0;
  Map<String, dynamic>? _currentPopupNotification;
  final NotificationStreamService _notificationService =
      NotificationStreamService();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _setupNotificationService();
  }

  void _setupNotificationService() {
    // Set up callback for new notifications
    _notificationService.setNotificationCallback((notification) {
      if (mounted) {
        setState(() {
          _currentPopupNotification = notification;
        });
      }
    });

    // Listen to unread count changes
    _notificationService.unreadCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    });

    // Initialize the service
    _notificationService.initialize();
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }

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
            _userName = data['name'] ?? 'User';
            _userPhone = data['phone'] ?? '';
            _userType = data['user_type'] ?? 'customer';
            _isLoading = false;
          });
          // Cache
          prefs.setString('user_name', _userName);
          prefs.setString('user_phone', _userPhone);
          prefs.setString('user_type', _userType);
        }
      }

      // Load application status after profile
      await _loadApplicationStatus();

      // Also load initial notification count
      await _loadInitialNotificationCount();
    } catch (e) {
      debugPrint('Profile load error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadApplicationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId == null) return;

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://chareta.com/riderhub/api/api.php?action=rider_application_status',
            ),
            headers: {'X-Session-Id': sessionId},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _applicationData = data;
        });
        debugPrint('Application status loaded: $data');
      }
    } catch (e) {
      debugPrint('Application status load error: $e');
    }
  }

  Future<void> _loadInitialNotificationCount() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://chareta.com/riderhub/api/api.php?action=get_unread_notification_count',
        ),
        headers: {'X-Session-Id': sessionId},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _notificationCount = data['unread_count'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Load notification count error: $e');
    }
  }

  void _handleNotificationPopupTap() {
    if (_currentPopupNotification != null) {
      // Mark as read
      final notificationId = _currentPopupNotification!['id'];
      if (notificationId != null) {
        _notificationService.markAsRead(notificationId);
      }

      // Navigate to notifications screen
      setState(() => _currentIndex = 2);

      // Clear the popup
      setState(() => _currentPopupNotification = null);
    }
  }

  Future<void> _logout() async {
    _notificationService.stopPolling();
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

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  // Check if user can apply to be a rider
  bool get _canApplyForRider {
    // User can apply if:
    // 1. They are a regular customer (user_type = 'customer')
    // 2. AND they haven't applied yet (status = 'not_applied' or null)
    final status =
        _applicationData?['status']?.toString().toLowerCase() ?? 'not_applied';
    return _userType == 'customer' && status == 'not_applied';
  }

  Widget _buildApplicationStatusCard() {
    final status =
        _applicationData?['status']?.toString().toLowerCase() ?? 'not_applied';
    final riderCode = _applicationData?['rider_code'];
    final rejectionReason = _applicationData?['rejection_reason'];

    debugPrint(
      'Building status card - Status: $status, User Type: $_userType, Rider Code: $riderCode',
    );

    // If user has applied OR is a pending_rider, show status card
    if (status != 'not_applied' || _userType == 'pending_rider') {
      Color statusColor;
      IconData statusIcon;
      String statusTitle;
      String statusSubtitle;
      String buttonText;
      bool showBadge = false;
      String badgeText = '';

      // Determine the actual status to display
      String displayStatus = status;
      if (_userType == 'pending_rider' && status == 'not_applied') {
        displayStatus = 'pending';
      }

      switch (displayStatus) {
        case 'pending':
          statusColor = Colors.orange;
          statusIcon = Icons.hourglass_empty;
          statusTitle = 'Application Under Review';
          statusSubtitle = 'Your application is being processed';
          buttonText = 'CHECK STATUS';
          showBadge = true;
          badgeText = 'PENDING';
          break;

        case 'approved':
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
          statusTitle = 'Congratulations!';
          statusSubtitle = riderCode != null
              ? 'Your Rider Code: $riderCode'
              : 'You are now a Chareta Rider!';
          buttonText = 'GO TO RIDER DASHBOARD';
          showBadge = true;
          badgeText = 'APPROVED';
          break;

        case 'rejected':
          statusColor = Colors.red;
          statusIcon = Icons.warning;
          statusTitle = 'Application Update';
          statusSubtitle = rejectionReason != null
              ? 'Reason: $rejectionReason'
              : 'Your application needs attention';
          buttonText = 'VIEW DETAILS';
          showBadge = true;
          badgeText = 'ACTION REQUIRED';
          break;

        default:
          statusColor = Colors.grey;
          statusIcon = Icons.help_outline;
          statusTitle = 'Application Status';
          statusSubtitle = 'Status: $displayStatus';
          buttonText = 'CHECK STATUS';
      }

      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusSubtitle,
                          style: GoogleFonts.inter(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showBadge)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RiderStatusScreen(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If user can apply (regular customer with no application), show the "Become a Rider" card
    if (_canApplyForRider) {
      return Card(
        elevation: 2,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.motorcycle, color: Color(0xFF667eea)),
          ),
          title: Text(
            'Become a Rider',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('Earn extra income delivering with Chareta'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ApplyRiderScreen()),
          ),
        ),
      );
    }

    // If none of the above conditions are met, return an empty container
    return const SizedBox.shrink();
  }

  Widget _buildNotificationIndicator() {
    if (_notificationCount > 0) {
      return Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => setState(() => _currentIndex = 2),
            tooltip: 'Notifications',
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _notificationCount > 9 ? '9+' : '$_notificationCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: () => setState(() => _currentIndex = 2),
        tooltip: 'Notifications',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeTab(),
      const DeliveryHistoryScreen(),
      NotificationsScreen(
        onNotificationsRead: () {
          // This will refresh the count when notifications are read
          _notificationService.refresh();
        },
      ),
      const SettingsScreen(),
    ];

    var _unreadCount = 0;
    return Scaffold(
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 140.0, // Enough space for clean logo placement
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Padding(
                    padding: const EdgeInsets.only(
                      left: 72.0,
                      bottom: 8.0,
                    ), // Space for logo on left
                    child: Text(
                      'Hello, ${_userName.split(' ').first}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF667eea),
                          Color(0xFF764ba2),
                          Color(0xFFf093fb),
                        ],
                        stops: [0.0, 0.6, 1.0],
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Very subtle decorative elements (almost invisible when collapsed)
                        Positioned(
                          left: -80,
                          top: -80,
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                        ),

                        // Circular logo on the LEFT – clean & professional
                        Positioned(
                          left: 24,
                          bottom:
                              16, // Slightly overlaps body edge when collapsed → looks intentional
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.20),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withOpacity(0.45),
                                width: 2.2,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.delivery_dining_rounded,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  _buildNotificationIndicator(),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: _logout,
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ],
            body: pages[_currentIndex],
          ),

          // Notification popup overlay
          if (_currentPopupNotification != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: NotificationPopup(
                notification: _currentPopupNotification!,
                onClose: () {
                  if (mounted) {
                    setState(() => _currentPopupNotification = null);
                  }
                },
                onTap: _handleNotificationPopupTap,
              ),
            ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SendRequestScreen()),
              ),
              backgroundColor: const Color(0xFF667eea),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'New Request',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF667eea),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.message_outlined),
                if (_unreadCount >
                    0) // ← use your existing _notificationCount or rename
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserProfile();
        await _loadApplicationStatus();
        await _notificationService.refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const SizedBox(height: 2),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _actionCard(
                  Icons.send_outlined,
                  'Send Request',
                  const Color(0xFF667eea),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SendRequestScreen(),
                      ),
                    );
                  },
                ),
                _actionCard(
                  Icons.track_changes,
                  'Track Delivery',
                  Colors.green,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrackDeliveryWrapperScreen(),
                      ),
                    );
                  },
                ),
                _actionCard(
                  Icons.notifications_active,
                  'Notifications',
                  _notificationCount > 0
                      ? Colors.red.shade700
                      : Colors.red.shade700,
                  () {
                    setState(() => _currentIndex = 2);
                  },
                  badgeCount: _notificationCount,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Rider Application Section
            _buildApplicationStatusCard(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap, {
    int badgeCount = 0,
  }) {
    return Stack(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 34, color: color),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 50, minHeight: 50),
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
