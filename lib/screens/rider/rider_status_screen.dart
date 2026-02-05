// lib/screens/customer/rider_status_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:riderhub/screens/customer/apply_rider_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class RiderStatusScreen extends StatefulWidget {
  const RiderStatusScreen({super.key});

  @override
  State<RiderStatusScreen> createState() {
    return _RiderStatusScreenState();
  }
}

class _RiderStatusScreenState extends State<RiderStatusScreen> {
  Map<String, dynamic>? _applicationData;
  bool _isLoading = true;
  String? _error;
  bool _showDebugPanel = true; // Set false in production
  Timer? _refreshTimer;
  bool _autoRefreshEnabled = true;
  int _refreshCount = 0;

  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _loadApplicationStatus();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_autoRefreshEnabled && mounted) {
        _refreshCount++;
        _addDebug('Auto-refresh #$_refreshCount triggered');
        _loadApplicationStatus(silent: true);
      }
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefreshEnabled = !_autoRefreshEnabled;
    });
    if (_autoRefreshEnabled) {
      _startAutoRefresh();
    } else {
      _stopAutoRefresh();
    }
    _addDebug('Auto-refresh ${_autoRefreshEnabled ? 'enabled' : 'disabled'}');
  }

  void _addDebug(String message) {
    if (!mounted) return;

    final time = DateTime.now().toString().substring(11, 23);
    final line = '[$time] $message';
    debugPrint('RIDER_STATUS_DEBUG: $line');

    if (mounted) {
      setState(() {
        // Keep only last 20 debug lines to prevent memory issues
        final lines = _debugInfo.split('\n');
        if (lines.length > 20) {
          _debugInfo = lines.sublist(lines.length - 20).join('\n') + '\n';
        }
        _debugInfo += '$line\n';
      });
    }
  }

  Future<void> _loadApplicationStatus({bool silent = false}) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final sessionId =
        prefs.getString('session_id') ?? prefs.getString('user_id');
    final cachedRiderCode = prefs.getString('rider_code');

    _addDebug('${silent ? '[Silent] ' : ''}Status check: Session="$sessionId"');

    if (sessionId == null || sessionId.trim().isEmpty) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'No session found. Please log in again.';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://chareta.com/riderhub/api/api.php?action=rider_application_status',
            ),
            headers: {'X-Session-Id': sessionId},
          )
          .timeout(
            const Duration(seconds: 10),
          ); // Shorter timeout for auto-refresh

      _addDebug('HTTP ${response.statusCode} ${silent ? '(silent)' : ''}');

      if (!mounted) return;

      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        try {
          final data = jsonDecode(response.body);

          // Cache rider_code if present
          if (data is Map<String, dynamic> && data['rider_code'] != null) {
            await prefs.setString('rider_code', data['rider_code']);
          }

          // Only update UI if data changed or it's not a silent refresh
          final String? newStatus = data['status']?.toString().trim();
          final String? currentStatus = _applicationData?['status']
              ?.toString()
              .trim();

          if (!silent || newStatus != currentStatus) {
            setState(() {
              _applicationData = data is Map<String, dynamic> ? data : null;
              _isLoading = false;
            });
            _addDebug('Status updated: $newStatus');
          } else if (silent) {
            _addDebug('[Silent] Status unchanged: $newStatus');
          }

          return;
        } catch (e) {
          _addDebug('JSON parse failed: $e');
        }
      }

      // === FALLBACK LOGIC: API failed or returned garbage ===
      if (!silent) {
        _addDebug('API failed → using fallback logic');

        if (cachedRiderCode != null && cachedRiderCode.startsWith('RDR-')) {
          _addDebug('Found cached rider_code → showing PENDING');
          setState(() {
            _applicationData = {
              'status': 'pending',
              'rider_code': cachedRiderCode,
            };
            _isLoading = false;
          });
        } else {
          setState(() {
            _error =
                'Server temporarily unavailable. Showing last known status.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      _addDebug('${silent ? '[Silent] ' : ''}Exception: $e');
      if (!silent && mounted) {
        // Even on timeout/exception → try to show cached status
        if (cachedRiderCode != null && cachedRiderCode.startsWith('RDR-')) {
          _addDebug(
            'Network error but cached rider_code exists → showing PENDING',
          );
          setState(() {
            _applicationData = {
              'status': 'pending',
              'rider_code': cachedRiderCode,
            };
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Connection failed. Retrying...';
            _isLoading = false;
          });
        }
      }
    }
  }

  Widget _buildStatusView({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? riderCode,
    Widget? actionButton,
    bool showAutoRefresh = true,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 100, color: color),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          if (riderCode != null) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    'Rider Code',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    riderCode,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showAutoRefresh && _applicationData?['status'] == 'pending') ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _autoRefreshEnabled ? Icons.refresh : Icons.refresh,
                  color: _autoRefreshEnabled ? Colors.blue : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Auto-refresh: ',
                  style: GoogleFonts.inter(color: Colors.grey[600]),
                ),
                Switch(
                  value: _autoRefreshEnabled,
                  onChanged: (value) => _toggleAutoRefresh(),
                  activeColor: Colors.blue,
                ),
              ],
            ),
            Text(
              'Next check: ${_refreshTimer != null ? 'Active' : 'Disabled'}',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
          if (actionButton != null) ...[
            const SizedBox(height: 40),
            actionButton,
          ],
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircularProgressIndicator(color: Color(0xFF667eea)),
            SizedBox(height: 20),
            Text('Checking your application status...'),
            SizedBox(height: 10),
            Text(
              'Auto-refresh every 5 seconds',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.cloud_off, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            Text(
              'Temporary Server Issue',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _loadApplicationStatus(silent: false),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _toggleAutoRefresh,
              icon: Icon(
                _autoRefreshEnabled ? Icons.toggle_on : Icons.toggle_off,
                color: _autoRefreshEnabled ? Colors.green : Colors.grey,
              ),
              label: Text(
                _autoRefreshEnabled ? 'Auto-refresh ON' : 'Auto-refresh OFF',
                style: TextStyle(
                  color: _autoRefreshEnabled ? Colors.green : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final String? rawStatus = _applicationData?['status']?.toString().trim();
    final String status = (rawStatus ?? '').toLowerCase();

    _addDebug('Current status: "$status"');

    if (status == 'not_applied' || status.isEmpty || _applicationData == null) {
      return _buildStatusView(
        icon: Icons.motorcycle,
        color: const Color(0xFF667eea),
        title: 'Become a Chareta Rider!',
        subtitle:
            'Earn money on your own schedule.\nFlexible hours • Great earnings',
        showAutoRefresh: false,
        actionButton: ElevatedButton.icon(
          icon: const Icon(Icons.how_to_reg, size: 28),
          label: const Text('Apply Now', style: TextStyle(fontSize: 20)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
            shape: const StadiumBorder(),
          ),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ApplyRiderScreen()),
            );
          },
        ),
      );
    }

    if (status == 'pending') {
      return _buildStatusView(
        icon: Icons.hourglass_empty,
        color: Colors.orange,
        title: 'Application Under Review',
        subtitle:
            'We are reviewing your documents.\nThis usually takes 1–3 business days.\n\nPage auto-refreshes every 5 seconds.',
        riderCode: _applicationData?['rider_code'],
        showAutoRefresh: true,
        actionButton: ElevatedButton(
          onPressed: () => _loadApplicationStatus(silent: false),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh),
              SizedBox(width: 8),
              Text('Refresh Now'),
            ],
          ),
        ),
      );
    }

    if (status == 'approved') {
      // Stop auto-refresh once approved
      if (_autoRefreshEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _toggleAutoRefresh();
        });
      }

      return _buildStatusView(
        icon: Icons.check_circle,
        color: Colors.green,
        title: 'Approved!',
        subtitle: 'Welcome aboard! You are now an official Chareta Rider.',
        riderCode: _applicationData?['rider_code'],
        showAutoRefresh: false,
        actionButton: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
          ),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/rider-home',
              (route) => false,
            );
          },
          child: const Text(
            'Go to Rider Dashboard',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      );
    }

    if (status == 'rejected') {
      // Stop auto-refresh if rejected
      if (_autoRefreshEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _toggleAutoRefresh();
        });
      }

      final reason =
          _applicationData?['rejection_reason'] ?? 'No reason provided.';
      return _buildStatusView(
        icon: Icons.cancel,
        color: Colors.red,
        title: 'Application Rejected',
        subtitle: reason,
        showAutoRefresh: false,
        actionButton: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ApplyRiderScreen()),
            );
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.replay),
              SizedBox(width: 8),
              Text('Re-apply Now'),
            ],
          ),
        ),
      );
    }

    return _buildStatusView(
      icon: Icons.help_outline,
      color: Colors.grey,
      title: 'Unknown Status',
      subtitle: 'Status: $status\nPlease contact support.',
      showAutoRefresh: false,
      actionButton: ElevatedButton(
        onPressed: () => _loadApplicationStatus(silent: false),
        child: const Text('Retry'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Application Status'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_applicationData?['status'] == 'pending')
            IconButton(
              icon: Icon(
                _autoRefreshEnabled ? Icons.refresh : Icons.refresh,
                color: Colors.white,
              ),
              onPressed: _toggleAutoRefresh,
              tooltip: _autoRefreshEnabled
                  ? 'Auto-refresh enabled'
                  : 'Auto-refresh disabled',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Auto-refresh Info'),
                  content: Text(
                    'This page automatically checks for status updates every 5 seconds.\n\n'
                    'Current status: ${_applicationData?['status'] ?? 'Unknown'}\n'
                    'Auto-refresh: ${_autoRefreshEnabled ? 'ON' : 'OFF'}\n'
                    'Refresh count: $_refreshCount',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Column(children: <Widget>[Expanded(child: _buildMainContent())]),

          // Auto-refresh indicator (top right corner)
          if (_autoRefreshEnabled && _applicationData?['status'] == 'pending')
            Positioned(
              top: 70,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.autorenew, size: 14, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Auto-refresh',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _showDebugPanel
          ? FloatingActionButton(
              mini: true,
              backgroundColor: Colors.grey,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Debug Info'),
                    content: SingleChildScrollView(child: Text(_debugInfo)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _debugInfo = '';
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
              child: const Icon(Icons.bug_report),
            )
          : null,
    );
  }
}
