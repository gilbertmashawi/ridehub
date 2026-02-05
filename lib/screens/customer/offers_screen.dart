// lib/screens/customer/offers_screen.dart
// Enhanced with session-based auth, proper API endpoints, pull-to-refresh, empty state, and improved error handling
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:riderhub/screens/customer/track_delivery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
// Assuming this exists for navigation after accept

class OffersScreen extends StatefulWidget {
  final String requestId;
  const OffersScreen({super.key, required this.requestId});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  List<Map<String, dynamic>> _offers = [];
  Timer? _timer;
  int _bidsCount = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _fetchOffers();
    _startTimer();
  }

  Future<String?> _getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_id');
  }

  Future<void> _fetchOffers() async {
    final sessionId = await _getSessionId();
    if (sessionId == null) {
      _showError('No active session. Please log in again.');
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://chareta.com/riderhub/api/api.php?action=offers&request_id=${widget.requestId}',
            ),
            headers: {
              'X-Session-Id': sessionId,
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('Fetch Offers Response status: ${response.statusCode}');
      debugPrint('Fetch Offers Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData.containsKey('error')) {
          _showError('Failed to fetch offers: ${responseData['error']}');
        } else {
          setState(() {
            _offers = List<Map<String, dynamic>>.from(
              responseData['offers'] ?? [],
            );
            _bidsCount = _offers.length;
            // Enhance data with defaults
            for (var offer in _offers) {
              offer['timeLeft'] = offer['time_left'] ?? 60;
              offer['rating'] = offer['rating'] ?? 4.5;
              offer['eta'] = '${offer['eta_mins'] ?? 5} mins';
              offer['rider'] = offer['rider_name'] ?? 'Unknown Rider';
              offer['fare'] = offer['fare'] ?? 0.0;
            }
            _isLoading = false;
          });
        }
      } else {
        _showError('Server error: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Fetch Offers Error: $e');
      _showError('Network error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      setState(() {
        for (var offer in _offers) {
          if (offer['timeLeft'] > 0) {
            offer['timeLeft'] = (offer['timeLeft'] - 5).clamp(0, 60);
          }
        }
      });
      // Refetch every 60s (12 ticks)
      if (_timer!.tick % 12 == 0) {
        _fetchOffers();
      }
    });
  }

  Future<void> _acceptBid(Map<String, dynamic> offer) async {
    final sessionId = await _getSessionId();
    if (sessionId == null) return;

    try {
      final response = await http
          .post(
            Uri.parse(
              'https://chareta.com/riderhub/api/api.php?action=offers_accept&offer_id=${offer['id']}',
            ),
            headers: {
              'X-Session-Id': sessionId,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({}), // Empty body as per API
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('Accept Bid Response status: ${response.statusCode}');
      debugPrint('Accept Bid Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (!responseData.containsKey('error')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Accepted bid from ${offer['rider']}! Rider assigned.',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
            // Navigate to track screen with delivery_id
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CustomerTrackingScreen(
                  // deliveryId: responseData['delivery_id']?.toString() ?? '',
                  deliveryId: responseData['delivery_id'] ?? '',
                ),
              ),
            );
          }
        } else {
          _showError('Accept failed: ${responseData['error']}');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Accept Bid Error: $e');
      _showError('Network error: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Live Bids for Request #${widget.requestId}',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Bids: $_bidsCount',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading bids...'),
                ],
              ),
            )
          : Container(
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  // Timer Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.orange.shade50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Bids closing in 60s – Choose quickly!',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        setState(() => _isRefreshing = true);
                        await _fetchOffers();
                        setState(() => _isRefreshing = false);
                      },
                      child: _offers.isEmpty
                          ? ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.hourglass_empty_outlined,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No bids yet',
                                        style: GoogleFonts.inter(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Nearby riders will see your request soon. Pull to refresh.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _offers.length,
                              itemBuilder: (context, index) {
                                final offer = _offers[index];
                                final isExpired = offer['timeLeft'] == 0;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: const Color(
                                                0xFF667eea,
                                              ).withOpacity(0.1),
                                              child: Text(
                                                offer['rider'][0].toUpperCase(),
                                                style: const TextStyle(
                                                  color: Color(0xFF667eea),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    offer['rider'],
                                                    style: GoogleFonts.inter(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.star,
                                                        color: Colors.amber,
                                                        size: 16,
                                                      ),
                                                      Text(
                                                        '${offer['rating'].toStringAsFixed(1)}/5',
                                                        style:
                                                            GoogleFonts.inter(
                                                              fontSize: 14,
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (!isExpired)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  '${offer['timeLeft']}s left',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Fare: \$${offer['fare'].toStringAsFixed(2)} | ETA: ${offer['eta']}',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: isExpired
                                                ? null
                                                : () => _acceptBid(offer),
                                            icon: const Icon(
                                              Icons.check,
                                              size: 18,
                                            ),
                                            label: Text(
                                              isExpired
                                                  ? 'Expired'
                                                  : 'Accept Bid',
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF667eea,
                                              ),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              elevation: 2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
