// lib/screens/rider/wallet_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _walletBalance = 0.0;
  List<TopUpHistory> _topUpHistory = [];
  bool _isLoading = true;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _amountController = TextEditingController();
  final List<double> _quickAmounts = [1.0, 2.0, 3.0, 5.0];

  static const String _baseUrl = 'https://chareta.com/riderhub/api/api.php';

  Future<String?> _getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_id');
  }

  Future<bool> _isLoggedIn() async {
    final sid = await _getSessionId();
    return sid != null && sid.isNotEmpty;
  }

  Future<Map<String, String>> _getHeaders({bool multipart = false}) async {
    final sid = await _getSessionId();
    final headers = <String, String>{};

    if (!multipart) {
      headers['Content-Type'] = 'application/json';
    }

    if (sid != null && sid.isNotEmpty) {
      headers['X-Session-Id'] = sid;
    }

    print("Sending headers: $headers"); // Debug
    return headers;
  }

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    if (!await _isLoggedIn()) {
      if (mounted) {
        _showSnack("Please login first", Colors.red);
      }
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final headers = await _getHeaders();

      // 1. Wallet balance
      final balanceUri = Uri.parse('$_baseUrl?action=get_wallet_balance');
      print("Fetching balance from: $balanceUri");
      final balanceRes = await http.get(balanceUri, headers: headers);

      print("Balance response → ${balanceRes.statusCode} | ${balanceRes.body}");

      if (balanceRes.statusCode == 403) {
        throw Exception("Session expired or unauthorized. Please login again.");
      }
      if (balanceRes.statusCode != 200) {
        throw Exception("Balance fetch failed: ${balanceRes.statusCode}");
      }

      final balanceJson = jsonDecode(balanceRes.body);
      if (balanceJson.containsKey('error')) {
        throw Exception(balanceJson['error']);
      }

      // Safe parsing for balance (handles string "0.00", null, or number)
      final balanceRaw = balanceJson['balance'];
      _walletBalance = (balanceRaw is num)
          ? balanceRaw.toDouble()
          : double.tryParse(balanceRaw?.toString() ?? '0') ?? 0.0;

      print("Parsed balance: $_walletBalance (raw: $balanceRaw)");

      // 2. Top-up history
      final historyUri = Uri.parse('$_baseUrl?action=get_topup_history');
      print("Fetching history from: $historyUri");
      final historyRes = await http.get(historyUri, headers: headers);

      print("History response → ${historyRes.statusCode} | ${historyRes.body}");

      if (historyRes.statusCode != 200) {
        throw Exception("History fetch failed: ${historyRes.statusCode}");
      }

      final historyJson = jsonDecode(historyRes.body);
      if (historyJson.containsKey('error')) {
        throw Exception(historyJson['error']);
      }

      final List<dynamic> historyList = historyJson['history'] ?? [];
      _topUpHistory = historyList.map((e) => TopUpHistory.fromJson(e)).toList();

      if (mounted) setState(() {});
    } catch (e) {
      print("Wallet load error: $e");
      if (mounted) {
        _showSnack("Failed to load wallet: $e", Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _submitTopUp() async {
    if (!await _isLoggedIn()) {
      _showSnack("Please login first", Colors.red);
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnack('Please enter amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 1 || amount > 100) {
      _showSnack('Amount must be between \$1 and \$100');
      return;
    }

    if (_selectedImage == null) {
      _showSnack('Please upload proof of payment');
      return;
    }

    final validDays = _calculateValidDays(amount);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl?action=submit_topup'),
      );

      final sid = await _getSessionId();
      if (sid != null && sid.isNotEmpty) {
        request.headers['X-Session-Id'] = sid;
      }

      request.fields['amount'] = amount.toStringAsFixed(2);
      request.fields['valid_days'] = validDays.toString();

      request.files.add(
        await http.MultipartFile.fromPath(
          'proof_image',
          _selectedImage!.path,
          filename: 'proof_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      print("Submitting top-up → URL: ${request.url}");
      print("Headers: ${request.headers}");
      print("Fields: ${request.fields}");
      print(
        "File: ${request.files.isNotEmpty ? request.files.first.filename : 'none'}",
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      print("Submit response → ${response.statusCode} | ${response.body}");

      if (response.statusCode == 403) {
        throw Exception("Session expired or unauthorized. Please login again.");
      }

      if (response.statusCode != 200) {
        throw Exception(
          "Submit failed: ${response.statusCode} - ${response.body}",
        );
      }

      final jsonRes = jsonDecode(response.body);
      if (jsonRes['success'] != true) {
        throw Exception(
          jsonRes['error'] ?? jsonRes['message'] ?? 'Unknown error',
        );
      }

      if (mounted) {
        _showSnack('Top-up request submitted successfully!', Colors.green);
        _amountController.clear();
        setState(() => _selectedImage = null);
        _loadWalletData();
      }
    } catch (e) {
      print("Submit top-up error: $e");
      if (mounted) {
        _showSnack('Failed to submit: $e', Colors.red);
      }
    }
  }

  void _selectQuickAmount(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(0);
    });
    final days = _calculateValidDays(amount);
    _showSnack('Selected: \$$amount → $days days');
  }

  int _calculateValidDays(double amount) => (amount * 7).toInt();

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      case 'pending':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade500;
    }
  }

  void _showSnack(String message, [Color bgColor = Colors.blueGrey]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Wallet & Top-up',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadWalletData,
        color: const Color(0xFF667eea),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(child: _buildBalanceCard()),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(child: _buildTopUpCard()),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Top-up History',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  if (_topUpHistory.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No top-up history yet',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: _buildHistoryItem(_topUpHistory[index]),
                        ),
                        childCount: _topUpHistory.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Current Balance',
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${_walletBalance.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF667eea),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_rounded,
                    size: 18,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Balance determines active days • Top-up to extend service',
                      style: GoogleFonts.inter(fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUpCard() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final days = _calculateValidDays(amount);
    final isCustomFilled = _amountController.text.trim().isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Up Wallet',
              style: GoogleFonts.inter(
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select or enter amount • Upload proof',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.05,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _quickAmounts.length,
              itemBuilder: (context, i) {
                final amt = _quickAmounts[i];
                final selected =
                    _amountController.text == amt.toStringAsFixed(0);

                return GestureDetector(
                  onTap: () => _selectQuickAmount(amt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF667eea) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF667eea),
                        width: 1.5,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF667eea).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${amt.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF667eea),
                            ),
                          ),
                          Text(
                            '${_calculateValidDays(amt)}d',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: selected
                                  ? Colors.white70
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Custom amount (USD)',
                prefixIcon: const Icon(Icons.attach_money_rounded, size: 22),
                suffixText: 'USD',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            if (isCustomFilled) ...[
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(amount),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$days days validity',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            Text(
              'Proof of Payment',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedImage != null
                        ? const Color(0xFF667eea)
                        : Colors.grey.shade300,
                    width: _selectedImage != null ? 2 : 1,
                  ),
                ),
                child: _selectedImage == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap to upload receipt',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedImage = null),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.black.withOpacity(0.65),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _submitTopUp,
                icon: const Icon(Icons.upload_rounded),
                label: Text(
                  'Submit Request',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(TopUpHistory item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 36,
            decoration: BoxDecoration(
              color: _getStatusColor(item.status),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '\$${item.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(item.status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.status.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _getStatusColor(item.status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.date,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (item.notes?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.notes!,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TopUpHistory {
  final String id;
  final double amount;
  final int validDays;
  final String status;
  final String date;
  final String? notes;

  TopUpHistory({
    required this.id,
    required this.amount,
    required this.validDays,
    required this.status,
    required this.date,
    this.notes,
  });

  factory TopUpHistory.fromJson(Map<String, dynamic> json) {
    // Safe numeric parsing
    final amountRaw = json['amount'];
    final amountParsed = (amountRaw is num)
        ? amountRaw.toDouble()
        : double.tryParse(amountRaw?.toString() ?? '0') ?? 0.0;

    final daysRaw = json['valid_days'];
    final daysParsed = (daysRaw is num)
        ? daysRaw.toInt()
        : int.tryParse(daysRaw?.toString() ?? '0') ?? 0;

    return TopUpHistory(
      id: json['id']?.toString() ?? '',
      amount: amountParsed,
      validDays: daysParsed,
      status: json['status']?.toString() ?? 'pending',
      date: json['date']?.toString() ?? '',
      notes: json['notes']?.toString(),
    );
  }
}
