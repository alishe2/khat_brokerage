import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:khat_brokerage/features/farmers/presentation/withdraw_farmer_screen.dart';
import 'package:khat_brokerage/features/farmers/presentation/adjust_farmer_balance_screen.dart';

class FarmerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> farmer;

  const FarmerProfileScreen({
    super.key,
    required this.farmer,
  });

  @override
  State<FarmerProfileScreen> createState() =>
      _FarmerProfileScreenState();
}

class _FarmerProfileScreenState
    extends State<FarmerProfileScreen> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _farmer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarmer();
  }

  Future<void> _loadFarmer() async {
    try {
      final data = await _supabase
          .from('farmers')
          .select(
            'id, farmer_code, full_name, phone, current_balance, is_active',
          )
          .eq('id', widget.farmer['id'])
          .single();

      if (!mounted) return;

      setState(() {
        _farmer = Map<String, dynamic>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load farmer: $e'),
        ),
      );
    }
  }

  Future<void> _openWithdrawal() async {
    if (_farmer == null) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WithdrawFarmerScreen(
          farmer: _farmer!,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadFarmer();
    }
  }

  Future<void> _openAdjustment() async {
    if (_farmer == null) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdjustFarmerBalanceScreen(
          farmer: _farmer!,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadFarmer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Farmer Profile'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_farmer == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Farmer Profile'),
        ),
        body: const Center(
          child: Text('Farmer not found'),
        ),
      );
    }

    final farmer = _farmer!;

    final name = farmer['full_name'] ?? 'Unknown';
    final code = farmer['farmer_code'] ?? 'No ID';
    final phone = farmer['phone'] ?? 'No phone number';
    final balance = farmer['current_balance'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Profile'),
      ),

      body: RefreshIndicator(
        onRefresh: _loadFarmer,

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),

          child: Column(
            children: [
              const CircleAvatar(
                radius: 42,
                child: Icon(
                  Icons.agriculture_outlined,
                  size: 42,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                code,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    children: [
                      Text(
                        'Current Balance',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '$balance Birr',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,

                        child: FilledButton.icon(
                          onPressed: _openWithdrawal,
                          icon: const Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                          label: const Text(
                            'Withdraw Money',
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,

                        child: OutlinedButton.icon(
                          onPressed: _openAdjustment,
                          icon: const Icon(
                            Icons.edit_note,
                          ),
                          label: const Text(
                            'Adjust Balance',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: [
                    const ListTile(
                      title: Text(
                        'Farmer Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    ListTile(
                      leading: const Icon(
                        Icons.badge_outlined,
                      ),
                      title: const Text('Farmer ID'),
                      subtitle: Text(code),
                    ),

                    ListTile(
                      leading: const Icon(
                        Icons.person_outline,
                      ),
                      title: const Text('Full Name'),
                      subtitle: Text(name),
                    ),

                    ListTile(
                      leading: const Icon(
                        Icons.phone_outlined,
                      ),
                      title: const Text('Phone'),
                      subtitle: Text(phone),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: const [
                    ListTile(
                      leading: Icon(Icons.history),
                      title: Text(
                        'Transaction History',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No transactions recorded yet.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}