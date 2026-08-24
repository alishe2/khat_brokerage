import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;

  int _totalKilo = 0;
  double _totalSales = 0;
  double _totalCommission = 0;
  double _farmerAmount = 0;
  double _buyerDebt = 0;
  double _farmerWithdrawals = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final sales = await _supabase
          .from('sales')
          .select(
            'total_bundles, total_sales, commission_amount, farmer_amount',
          );

      final buyers = await _supabase
          .from('buyers')
          .select('current_debt');

      final withdrawals = await _supabase
          .from('farmer_withdrawals')
          .select('amount');

      int kilo = 0;
      double salesAmount = 0;
      double commission = 0;
      double farmers = 0;
      double debt = 0;
      double withdrawalsAmount = 0;

      for (final sale in sales) {
        kilo +=
            int.tryParse(
              sale['total_bundles']?.toString() ?? '0',
            ) ??
            0;

        salesAmount +=
            double.tryParse(
              sale['total_sales']?.toString() ?? '0',
            ) ??
            0;

        commission +=
            double.tryParse(
              sale['commission_amount']?.toString() ?? '0',
            ) ??
            0;

        farmers +=
            double.tryParse(
              sale['farmer_amount']?.toString() ?? '0',
            ) ??
            0;
      }

      for (final buyer in buyers) {
        debt +=
            double.tryParse(
              buyer['current_debt']?.toString() ?? '0',
            ) ??
            0;
      }

      for (final withdrawal in withdrawals) {
        withdrawalsAmount +=
            double.tryParse(
              withdrawal['amount']?.toString() ?? '0',
            ) ??
            0;
      }

      if (!mounted) return;

      setState(() {
        _totalKilo = kilo;
        _totalSales = salesAmount;
        _totalCommission = commission;
        _farmerAmount = farmers;
        _buyerDebt = debt;
        _farmerWithdrawals = withdrawalsAmount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load reports: $e',
          ),
        ),
      );
    }
  }

  String _money(double value) {
    return '${value.toStringAsFixed(2)} Birr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Business Reports',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Overall business performance',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Sales Performance',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _ReportCard(
                          title: 'Total Kilo Sold',
                          value: '$_totalKilo',
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ReportCard(
                          title: 'Total Sales',
                          value: _money(_totalSales),
                          icon: Icons.point_of_sale_outlined,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _ReportCard(
                    title: 'Total Commission',
                    value: _money(_totalCommission),
                    icon: Icons.account_balance_wallet_outlined,
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Farmer Financials',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _ReportCard(
                    title: 'Total Farmer Amount',
                    value: _money(_farmerAmount),
                    icon: Icons.agriculture_outlined,
                  ),

                  const SizedBox(height: 12),

                  _ReportCard(
                    title: 'Total Farmer Withdrawals',
                    value: _money(_farmerWithdrawals),
                    icon: Icons.arrow_downward,
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Buyer Financials',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _ReportCard(
                    title: 'Current Buyer Debt',
                    value: _money(_buyerDebt),
                    icon: Icons.credit_card_outlined,
                  ),

                  const SizedBox(height: 24),

                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                      ),
                      title: const Text(
                        'Report period',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Currently showing overall records. '
                        'Date-range reports will be added next.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(icon),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
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
}