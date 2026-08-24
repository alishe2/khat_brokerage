import 'package:flutter/material.dart';
import 'package:khat_brokerage/features/farmers/presentation/farmers_screen.dart';
import 'package:khat_brokerage/features/sales/presentation/record_sale_screen.dart';
import 'package:khat_brokerage/features/buyers/presentation/buyers_screen.dart';
import 'package:khat_brokerage/features/sellers/presentation/sellers_screen.dart';
import 'package:khat_brokerage/features/accountant/presentation/accountant_screen.dart';
import 'package:khat_brokerage/features/transactions/presentation/transactions_screen.dart';
import 'package:khat_brokerage/features/reports/presentation/reports_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good morning, Admin',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),

              Text(
                'Today\'s business overview',
                style: TextStyle(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 24),

              const Text(
                'Today',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _DashboardCard(
                      title: 'Kilo Sold',
                      value: '0',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DashboardCard(
                      title: 'Commission',
                      value: '0 Birr',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _DashboardCard(
                      title: 'Buyer Paid',
                      value: '0 Birr',
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DashboardCard(
                      title: 'Buyer Unpaid',
                      value: '0 Birr',
                      icon: Icons.money_off_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'Money Movement Today',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              _MoneyMovementTile(
                title: 'Farmer Withdrawals',
                amount: '0 Birr',
                icon: Icons.arrow_downward,
              ),

              _MoneyMovementTile(
                title: 'Worker Fees',
                amount: '0 Birr',
                icon: Icons.people_outline,
              ),

              _MoneyMovementTile(
                title: 'Owner Cash Flow',
                amount: '0 Birr',
                icon: Icons.account_balance_outlined,
              ),

              const SizedBox(height: 24),

              const Text(
                'Overall Business',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _DashboardCard(
                      title: 'Farmer Money',
                      value: '0 Birr',
                      icon: Icons.agriculture_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DashboardCard(
                      title: 'Buyer Debt',
                      value: '0 Birr',
                      icon: Icons.credit_card_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _ActionCard(
                    title: 'Record Sale',
                    icon: Icons.point_of_sale_outlined,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RecordSaleScreen(),
                        ),
                      );
                    },
                  ),

                  _ActionCard(
                    title: 'Farmers',
                    icon: Icons.agriculture_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FarmersScreen(),
                        ),
                      );
                    },
                  ),

                  _ActionCard(
                    title: 'Buyers',
                    icon: Icons.groups_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BuyersScreen()),
                      );
                    },
                  ),

                  _ActionCard(
                    title: 'Sellers',
                    icon: Icons.person_outline,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SellersScreen(),
                        ),
                      );
                    },
                  ),

                  _ActionCard(
                    title: 'Accountant',
                    icon: Icons.calculate_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountantScreen(),
                        ),
                      );
                    },
                  ),

                  _ActionCard(
                    title: 'Transactions',
                    icon: Icons.receipt_long_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TransactionsScreen(),
                        ),
                      );
                    },
                  ),

                  _ActionCard(
                    title: 'Reports',
                    icon: Icons.bar_chart_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReportsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyMovementTile extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;

  const _MoneyMovementTile({
    required this.title,
    required this.amount,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          amount,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
