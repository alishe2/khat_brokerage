import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:khat_brokerage/features/farmers/presentation/farmers_screen.dart';
import 'package:khat_brokerage/features/sales/presentation/record_sale_screen.dart';
import 'package:khat_brokerage/features/buyers/presentation/buyers_screen.dart';
import 'package:khat_brokerage/features/sellers/presentation/sellers_screen.dart';
import 'package:khat_brokerage/features/accountant/presentation/accountant_screen.dart';
import 'package:khat_brokerage/features/transactions/presentation/transactions_screen.dart';
import 'package:khat_brokerage/features/reports/presentation/reports_screen.dart';
import 'package:khat_brokerage/features/notifications/presentation/notifications_screen.dart';
import 'package:khat_brokerage/features/profile/presentation/admin_profile_screen.dart';
import 'package:khat_brokerage/features/worker_fees/presentation/worker_fees_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;

  int _kiloSoldToday = 0;

  double _commissionToday = 0;
  double _buyerPaidToday = 0;
  double _buyerUnpaidToday = 0;

  double _farmerMoney = 0;
  double _buyerDebt = 0;

  double _farmerWithdrawalsToday = 0;
  double _workerFeesToday = 0;

  // Null means today's worker fee has not been recorded yet.
  double? _ownerCashFlowToday;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final today = DateTime.now();

      final todayString =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      // ============================================================
      // TODAY'S SALES
      // ============================================================

      final salesData = await _supabase
          .from('sales')
          .select('total_bundles, commission_amount')
          .eq('sale_date', todayString);

      int kiloSold = 0;
      double commission = 0;

      for (final sale in salesData) {
        kiloSold +=
            (sale['total_bundles'] as num?)?.toInt() ?? 0;

        commission +=
            (sale['commission_amount'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // TODAY'S BUYER PAYMENTS FROM SALES
      // ============================================================

      final saleBuyerData = await _supabase
          .from('sale_buyers')
          .select(
            'paid_amount, unpaid_amount, sales!inner(sale_date)',
          )
          .eq('sales.sale_date', todayString);

      double buyerPaid = 0;
      double buyerUnpaid = 0;

      for (final buyer in saleBuyerData) {
        buyerPaid +=
            (buyer['paid_amount'] as num?)?.toDouble() ?? 0;

        buyerUnpaid +=
            (buyer['unpaid_amount'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // TOTAL FARMER MONEY
      // ============================================================

      final farmersData = await _supabase
          .from('farmers')
          .select('current_balance')
          .eq('is_active', true);

      double farmerMoney = 0;

      for (final farmer in farmersData) {
        farmerMoney +=
            (farmer['current_balance'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // TOTAL BUYER DEBT
      // ============================================================

      final buyersData = await _supabase
          .from('buyers')
          .select('current_debt')
          .eq('is_active', true);

      double buyerDebt = 0;

      for (final buyer in buyersData) {
        buyerDebt +=
            (buyer['current_debt'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // TODAY'S FARMER WITHDRAWALS
      // ============================================================

      final withdrawalsData = await _supabase
          .from('farmer_withdrawals')
          .select('amount')
          .eq('withdrawal_date', todayString);

      double farmerWithdrawals = 0;

      for (final withdrawal in withdrawalsData) {
        farmerWithdrawals +=
            (withdrawal['amount'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // TODAY'S WORKER FEES
      //
      // Existing table structure:
      // worker_fees
      // - id
      // - fee_date
      // - amount
      // - recorded_by
      // - created_at
      // ============================================================

      final workerFeeData = await _supabase
          .from('worker_fees')
          .select('amount')
          .eq('fee_date', todayString)
          .maybeSingle();

      double? workerFees;

      if (workerFeeData != null) {
        workerFees =
            (workerFeeData['amount'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // OWNER CASH FLOW
      //
      // Owner cash flow today:
      //
      // Commission
      // - Farmer withdrawals
      // - Worker fees
      //
      // Worker fees must exist before the day's owner cash flow
      // is considered finalized.
      // ============================================================

      double? ownerCashFlow;

      if (workerFees != null) {
        ownerCashFlow =
            commission -
            farmerWithdrawals -
            workerFees;
      }

      if (!mounted) return;

      setState(() {
        _kiloSoldToday = kiloSold;

        _commissionToday = commission;
        _buyerPaidToday = buyerPaid;
        _buyerUnpaidToday = buyerUnpaid;

        _farmerMoney = farmerMoney;
        _buyerDebt = buyerDebt;

        _farmerWithdrawalsToday = farmerWithdrawals;

        _workerFeesToday = workerFees ?? 0;
        _ownerCashFlowToday = ownerCashFlow;

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
            'Could not load dashboard: $e',
          ),
        ),
      );
    }
  }

  String _money(double amount) {
    return '${amount.toStringAsFixed(2)} Birr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),

        actions: [
          // ========================================================
          // NOTIFICATIONS
          // ========================================================

          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const NotificationsScreen(),
                ),
              );
            },
            tooltip: 'Notifications',
            icon: const Icon(
              Icons.notifications_none,
            ),
          ),

          // ========================================================
          // ADMIN PROFILE
          // ========================================================

          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const AdminProfileScreen(),
                ),
              );
            },
            tooltip: 'Account',
            icon: const Icon(
              Icons.account_circle_outlined,
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadDashboard,

        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // ======================================================
              // HEADER
              // ======================================================

              const Text(
                'Good morning, Admin',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Today\'s business overview',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 24),

              // ======================================================
              // TODAY
              // ======================================================

              const Text(
                'Today',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _DashboardCard(
                      title: 'Kilo Sold',
                      value: _isLoading
                          ? '...'
                          : '$_kiloSoldToday',
                      icon:
                          Icons.inventory_2_outlined,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _DashboardCard(
                      title: 'Commission',
                      value: _isLoading
                          ? '...'
                          : _money(
                              _commissionToday,
                            ),
                      icon: Icons
                          .account_balance_wallet_outlined,
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
                      value: _isLoading
                          ? '...'
                          : _money(
                              _buyerPaidToday,
                            ),
                      icon:
                          Icons.payments_outlined,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _DashboardCard(
                      title: 'Buyer Unpaid',
                      value: _isLoading
                          ? '...'
                          : _money(
                              _buyerUnpaidToday,
                            ),
                      icon:
                          Icons.money_off_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ======================================================
              // MONEY MOVEMENT TODAY
              // ======================================================

              const Text(
                'Money Movement Today',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              _MoneyMovementTile(
                title: 'Farmer Withdrawals',
                amount: _isLoading
                    ? '...'
                    : _money(
                        _farmerWithdrawalsToday,
                      ),
                icon: Icons.arrow_downward,
              ),

              _MoneyMovementTile(
                title: 'Worker Fees',
                amount: _isLoading
                    ? '...'
                    : _ownerCashFlowToday == null
                        ? 'Not recorded'
                        : _money(
                            _workerFeesToday,
                          ),
                icon: Icons.people_outline,
              ),

              _MoneyMovementTile(
                title: 'Owner Cash Flow',
                amount: _isLoading
                    ? '...'
                    : _ownerCashFlowToday == null
                        ? 'Pending'
                        : _money(
                            _ownerCashFlowToday!,
                          ),
                icon:
                    Icons.account_balance_outlined,
              ),

              const SizedBox(height: 24),

              // ======================================================
              // OVERALL BUSINESS
              // ======================================================

              const Text(
                'Overall Business',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _DashboardCard(
                      title: 'Farmer Money',
                      value: _isLoading
                          ? '...'
                          : _money(
                              _farmerMoney,
                            ),
                      icon:
                          Icons.agriculture_outlined,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _DashboardCard(
                      title: 'Buyer Debt',
                      value: _isLoading
                          ? '...'
                          : _money(
                              _buyerDebt,
                            ),
                      icon:
                          Icons.credit_card_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ======================================================
              // QUICK ACTIONS
              // ======================================================

              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,

                shrinkWrap: true,

                physics:
                    const NeverScrollableScrollPhysics(),

                crossAxisSpacing: 12,

                mainAxisSpacing: 12,

                childAspectRatio: 1.5,

                children: [
                  // ==================================================
                  // RECORD SALE
                  // ==================================================

                  _ActionCard(
                    title: 'Record Sale',
                    icon:
                        Icons.point_of_sale_outlined,

                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const RecordSaleScreen(),
                        ),
                      );

                      if (mounted) {
                        await _loadDashboard();
                      }
                    },
                  ),

                  // ==================================================
                  // FARMERS
                  // ==================================================

                  _ActionCard(
                    title: 'Farmers',
                    icon:
                        Icons.agriculture_outlined,

                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const FarmersScreen(),
                        ),
                      );

                      if (mounted) {
                        await _loadDashboard();
                      }
                    },
                  ),

                  // ==================================================
                  // BUYERS
                  // ==================================================

                  _ActionCard(
                    title: 'Buyers',
                    icon: Icons.groups_outlined,

                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const BuyersScreen(),
                        ),
                      );

                      if (mounted) {
                        await _loadDashboard();
                      }
                    },
                  ),

                  // ==================================================
                  // SELLERS
                  // ==================================================

                  _ActionCard(
                    title: 'Sellers',
                    icon: Icons.person_outline,

                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const SellersScreen(),
                        ),
                      );

                      if (mounted) {
                        await _loadDashboard();
                      }
                    },
                  ),

                  // ==================================================
                  // ACCOUNTANT
                  // ==================================================

                  _ActionCard(
                    title: 'Accountant',
                    icon:
                        Icons.calculate_outlined,

                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const AccountantScreen(),
                        ),
                      );
                    },
                  ),

                  // ==================================================
                  // TRANSACTIONS
                  // ==================================================

                  _ActionCard(
                    title: 'Transactions',
                    icon:
                        Icons.receipt_long_outlined,

                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const TransactionsScreen(),
                        ),
                      );
                    },
                  ),

                  // ==================================================
                  // REPORTS
                  // ==================================================

                  _ActionCard(
                    title: 'Reports',
                    icon:
                        Icons.bar_chart_outlined,

                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const ReportsScreen(),
                        ),
                      );
                    },
                  ),

                  // ==================================================
                  // WORKER FEES
                  // ==================================================

                  _ActionCard(
                    title: 'Worker Fees',
                    icon:
                        Icons.people_outline,

                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const WorkerFeesScreen(),
                        ),
                      );

                      if (mounted) {
                        await _loadDashboard();
                      }
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

// ==================================================================
// DASHBOARD CARD
// ==================================================================

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
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Icon(
              icon,
              size: 28,
            ),

            const SizedBox(height: 12),

            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// MONEY MOVEMENT TILE
// ==================================================================

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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// QUICK ACTION CARD
// ==================================================================

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

        borderRadius:
            BorderRadius.circular(12),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              size: 32,
            ),

            const SizedBox(height: 8),

            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}