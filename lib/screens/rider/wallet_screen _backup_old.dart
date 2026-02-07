// wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 245.50;
  double _todayEarnings = 32.75;
  double _weeklyEarnings = 168.25;

  final List<Map<String, dynamic>> _transactions = [
    {
      'id': '1',
      'date': '2024-01-15',
      'time': '14:30',
      'amount': 12.50,
      'type': 'delivery',
      'description': 'Package delivery - CBD to Avondale',
      'status': 'completed',
    },
    {
      'id': '2',
      'date': '2024-01-15',
      'time': '11:15',
      'amount': 8.75,
      'type': 'delivery',
      'description': 'Food delivery - Pizza Inn',
      'status': 'completed',
    },
    {
      'id': '3',
      'date': '2024-01-14',
      'amount': 45.00,
      'type': 'payout',
      'description': 'Weekly payout',
      'status': 'completed',
    },
    {
      'id': '4',
      'date': '2024-01-13',
      'time': '16:45',
      'amount': 15.00,
      'type': 'delivery',
      'description': 'Document delivery',
      'status': 'completed',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Wallet',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ---------------- TAB CONTROLLER ----------------
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: Color(0xFF667eea),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF667eea),
                tabs: [
                  Tab(text: "Top Up"),
                  Tab(text: "Payout"),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                children: [
                  // ---------------- TOP UP TAB ----------------
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildBalanceCard(),
                        const SizedBox(height: 24),
                        _buildTopUpCard(),
                      ],
                    ),
                  ),

                  // ---------------- PAYOUT TAB ----------------
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildBalanceCard(),
                        const SizedBox(height: 24),
                        _buildEarningsOverview(),
                        const SizedBox(height: 24),
                        _buildPayoutHistory(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestPayout,
        icon: const Icon(Icons.payment),
        label: const Text('Request Payout'),
        backgroundColor: const Color(0xFF667eea),
      ),
    );
  }

  // ---------------- BALANCE CARD ----------------
  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total Balance',
            style: GoogleFonts.inter(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '\$$_balance',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBalanceStat('Today', '\$$_todayEarnings'),
              _buildBalanceStat('This Week', '\$$_weeklyEarnings'),
              _buildBalanceStat('Jobs', '12'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  // ---------------- EARNINGS OVERVIEW ----------------
  Widget _buildEarningsOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earnings Overview',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildEarningRow('Today', _todayEarnings, Colors.green),
          _buildEarningRow('Yesterday', 28.50, Colors.green),
          _buildEarningRow('This Week', _weeklyEarnings, Colors.blue),
          _buildEarningRow('Last Week', 142.75, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildEarningRow(String period, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(period, style: GoogleFonts.inter(fontSize: 16)),
          Text(
            '\$$amount',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- TOP UP CARD (NEW) ----------------
  Widget _buildTopUpCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Top Up Options",
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTrendCard(Icons.phone_android, "Mobile Money"),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTrendCard(Icons.credit_card, "Card Top-Up"),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(child: _buildTrendCard(Icons.store, "Bank Deposit")),
              const SizedBox(width: 12),
              Expanded(child: _buildTrendCard(Icons.qr_code, "QR Top-Up")),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- TREND CARD (NEW) ----------------
  Widget _buildTrendCard(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: const Color(0xFF667eea)),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------- PAYOUT HISTORY ----------------
  Widget _buildPayoutHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payout History',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._transactions.map(_buildTransactionItem).toList(),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: transaction['type'] == 'payout'
                ? Colors.orange.shade100
                : Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            transaction['type'] == 'payout'
                ? Icons.payment
                : Icons.delivery_dining,
            color: transaction['type'] == 'payout'
                ? Colors.orange
                : Colors.green,
          ),
        ),
        title: Text(
          transaction['description'],
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${transaction['date']}${transaction['time'] != null ? ' • ${transaction['time']}' : ''}',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${transaction['amount']}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: transaction['type'] == 'payout'
                    ? Colors.orange
                    : Colors.green,
              ),
            ),
            Text(
              transaction['type'] == 'payout' ? 'Payout' : 'Earning',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- PAYOUT REQUEST ----------------
  void _requestPayout() {
    if (_balance < 10.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum payout amount is \$10.00'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Payout'),
        content: Text(
          'Request payout of \$$_balance to your registered bank account?',
          style: GoogleFonts.inter(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processPayout();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _processPayout() {
    setState(() {
      _transactions.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'date': '2024-01-16',
        'amount': _balance,
        'type': 'payout',
        'description': 'Payout request',
        'status': 'pending',
      });
      _balance = 0.0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payout request submitted successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
