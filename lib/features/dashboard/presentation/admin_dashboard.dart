import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:khat_brokerage/features/farmers/presentation/farmers_screen.dart';
import 'package:khat_brokerage/features/sales/presentation/record_sale_screen.dart';
import 'package:khat_brokerage/features/buyers/presentation/buyers_screen.dart';
import 'package:khat_brokerage/features/sellers/presentation/sellers_screen.dart';
import 'package:khat_brokerage/features/accountant/presentation/accountant_screen.dart';
import 'package:khat_brokerage/features/transactions/presentation/transactions_screen.dart';
import 'package:khat_brokerage/features/reports/presentation/reports_screen.dart';
import 'package:khat_brokerage/features/profile/presentation/admin_profile_screen.dart';
import 'package:khat_brokerage/features/expenses/presentation/other_expenses_screen.dart';

// A single shared corner radius so every card on this dashboard reads as
// one visual family, instead of three slightly different roundnesses.
const double _kCardRadius = 16;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;

  String _adminName = 'Administrator';

  int _kiloSoldToday = 0;

  double _commissionToday = 0;
  double _buyerPaidToday = 0;
  double _buyerUnpaidToday = 0;
  double _paidFromOldDebtToday = 0;
  double _totalPaidToday = 0;

  double _farmerMoney = 0;
  double _buyerDebt = 0;

  double _farmerWithdrawalsToday = 0;
  double _workerFeesToday = 0;
  double _otherExpensesToday = 0;

  // Null means today's worker fee has not been recorded yet.
  double? _adminProfitToday;

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

      final userId = _supabase.auth.currentUser?.id;

      // ============================================================
      // FIRE ALL NINE QUERIES AT ONCE
      //
      // None of these depend on each other's results — only on
      // `todayString` / `userId`, both already known above. Instead
      // of nine sequential round trips, we start them all at once
      // and wait for the slowest one, not the sum of all nine.
      // ============================================================

      final results = await Future.wait<dynamic>([
        // 0: admin name — placeholder keeps list positions stable
        // even when there's no userId to query with.
        userId != null
            ? _supabase
                  .from('users')
                  .select('full_name')
                  .eq('id', userId)
                  .maybeSingle()
            : Future.value(null),

        // 1: today's sales
        _supabase
            .from('sales')
            .select('total_bundles, commission_amount')
            .eq('sale_date', todayString),

        // 2: today's buyer payments from today's sales
        _supabase
            .from('sale_buyers')
            .select('paid_amount, unpaid_amount, sales!inner(sale_date)')
            .eq('sales.sale_date', todayString),

        // 3: paid from old debt
        _supabase
            .from('buyer_debt_payments')
            .select('amount')
            .eq('payment_date', todayString),

        // 4: total farmer money
        _supabase
            .from('farmers')
            .select('current_balance')
            .eq('is_active', true),

        // 5: total buyer debt
        _supabase.from('buyers').select('current_debt').eq('is_active', true),

        // 6: today's farmer withdrawals
        _supabase
            .from('farmer_withdrawals')
            .select('amount')
            .eq('withdrawal_date', todayString),

        // 7: today's worker fees
        _supabase
            .from('worker_fees')
            .select('amount')
            .eq('fee_date', todayString)
            .maybeSingle(),

        // 8: today's other expenses
        _supabase
            .from('other_expenses')
            .select('amount')
            .eq('expense_date', todayString),
      ]);

      // ============================================================
      // UNPACK RESULTS — same order the futures were listed above
      // ============================================================

      final userData = results[0] as Map<String, dynamic>?;
      final salesData = results[1] as List;
      final saleBuyerData = results[2] as List;
      final oldDebtPaymentsData = results[3] as List;
      final farmersData = results[4] as List;
      final buyersData = results[5] as List;
      final withdrawalsData = results[6] as List;
      final workerFeeData = results[7] as Map<String, dynamic>?;
      final otherExpensesData = results[8] as List;

      // ============================================================
      // ADMIN NAME
      // ============================================================

      String adminName = 'Administrator';

      if (userId != null) {
        adminName = userData?['full_name']?.toString().trim() ?? '';

        if (adminName.isEmpty) {
          adminName = 'Administrator';
        }
      }

      // ============================================================
      // TODAY'S SALES
      // ============================================================

      int kiloSold = 0;
      double commission = 0;

      for (final sale in salesData) {
        kiloSold += (sale['total_bundles'] as num?)?.toInt() ?? 0;
        commission += (sale['commission_amount'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // TODAY'S BUYER PAYMENTS FROM TODAY'S SALES
      // ============================================================

      double buyerPaid = 0;
      double buyerUnpaid = 0;

      for (final buyer in saleBuyerData) {
        buyerPaid += (buyer['paid_amount'] as num?)?.toDouble() ?? 0;
        buyerUnpaid += (buyer['unpaid_amount'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // PAID FROM OLD DEBT
      // ============================================================

      double paidFromOldDebt = 0;

      for (final payment in oldDebtPaymentsData) {
        paidFromOldDebt += (payment['amount'] as num?)?.toDouble() ?? 0;
      }

      final totalPaid = buyerPaid + paidFromOldDebt;

      // ============================================================
      // TOTAL FARMER MONEY
      // ============================================================

      double farmerMoney = 0;

      for (final farmer in farmersData) {
        farmerMoney += (farmer['current_balance'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // TOTAL BUYER DEBT
      // ============================================================

      double buyerDebt = 0;

      for (final buyer in buyersData) {
        buyerDebt += (buyer['current_debt'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // TODAY'S FARMER WITHDRAWALS
      // ============================================================

      double farmerWithdrawals = 0;

      for (final withdrawal in withdrawalsData) {
        farmerWithdrawals += (withdrawal['amount'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // TODAY'S WORKER FEES
      // ============================================================

      double? workerFees;

      if (workerFeeData != null) {
        workerFees = (workerFeeData['amount'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // TODAY'S OTHER EXPENSES
      // ============================================================

      double otherExpenses = 0;

      for (final expense in otherExpensesData) {
        otherExpenses += (expense['amount'] as num?)?.toDouble() ?? 0;
      }

      // ============================================================
      // ADMIN PROFIT
      // ============================================================

      double? adminProfit;

      if (workerFees != null) {
        adminProfit = commission - workerFees - otherExpenses;
      }

      if (!mounted) return;

      setState(() {
        _adminName = adminName;

        _kiloSoldToday = kiloSold;

        _commissionToday = commission;
        _buyerPaidToday = buyerPaid;
        _buyerUnpaidToday = buyerUnpaid;
        _paidFromOldDebtToday = paidFromOldDebt;
        _totalPaidToday = totalPaid;

        _farmerMoney = farmerMoney;
        _buyerDebt = buyerDebt;

        _farmerWithdrawalsToday = farmerWithdrawals;
        _workerFeesToday = workerFees ?? 0;
        _otherExpensesToday = otherExpenses;

        _adminProfitToday = adminProfit;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load dashboard: $e')));
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
          // ==========================================================
          // ADMIN PROFILE
          // ==========================================================
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
              );

              if (mounted) {
                await _loadDashboard();
              }
            },
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ======================================================
              // HEADER
              // ======================================================
              Text(
                'Welcome, $_adminName',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Today\'s business overview',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),

              // ======================================================
              // TODAY
              // ======================================================
              const Text(
                'Today',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 12) / 2;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _DashboardCard(
                          title: 'Kilo Sold',
                          value: _isLoading ? '...' : '$_kiloSoldToday',
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),

                      SizedBox(
                        width: cardWidth,
                        child: _DashboardCard(
                          title: 'Buyer Paid',
                          value: _isLoading ? '...' : _money(_buyerPaidToday),
                          icon: Icons.payments_outlined,
                        ),
                      ),

                      SizedBox(
                        width: cardWidth,
                        child: _DashboardCard(
                          title: 'Paid From Old Debt',
                          value: _isLoading
                              ? '...'
                              : _money(_paidFromOldDebtToday),
                          icon: Icons.history_outlined,
                        ),
                      ),

                      SizedBox(
                        width: cardWidth,
                        child: _DashboardCard(
                          title: 'Buyer Unpaid',
                          value: _isLoading ? '...' : _money(_buyerUnpaidToday),
                          icon: Icons.money_off_outlined,
                        ),
                      ),

                      SizedBox(
                        width: cardWidth,
                        child: _DashboardCard(
                          title: 'Total Paid',
                          value: _isLoading ? '...' : _money(_totalPaidToday),
                          icon: Icons.payments_outlined,
                        ),
                      ),

                      SizedBox(
                        width: cardWidth,
                        child: _DashboardCard(
                          title: 'Farmer Withdrawal',
                          value: _isLoading
                              ? '...'
                              : _money(_farmerWithdrawalsToday),
                          icon: Icons.arrow_downward,
                        ),
                      ),

                      // Commission is intentionally featured separately
                      // so it receives more visual attention.
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _FeaturedDashboardCard(
                          title: 'Commission',
                          value: _isLoading ? '...' : _money(_commissionToday),
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // ======================================================
              // WORKER FEES, OTHER EXPENSES & ADMIN PROFIT
              //
              // Now built with _MoneyMovementTile in the same visual
              // language as the cards above (same radius, same
              // icon-box treatment) instead of a bare default ListTile.
              // ======================================================
              _MoneyMovementTile(
                title: 'Worker Fees',
                amount: _isLoading
                    ? '...'
                    : _adminProfitToday == null
                    ? 'Not recorded'
                    : _money(_workerFeesToday),
                icon: Icons.people_outline,
              ),

              const SizedBox(height: 10),

              _MoneyMovementTile(
                title: 'Other Expenses',
                amount: _isLoading ? '...' : _money(_otherExpensesToday),
                icon: Icons.receipt_long_outlined,
              ),

              const SizedBox(height: 10),

              _MoneyMovementTile(
                title: 'Admin Profit',
                amount: _isLoading
                    ? '...'
                    : _adminProfitToday == null
                    ? 'Pending'
                    : _money(_adminProfitToday!),
                icon: Icons.account_balance_outlined,
              ),

              const SizedBox(height: 24),

              // ======================================================
              // OVERALL BUSINESS
              // ======================================================
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
                      value: _isLoading ? '...' : _money(_farmerMoney),
                      icon: Icons.agriculture_outlined,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _DashboardCard(
                      title: 'Buyer Debt',
                      value: _isLoading ? '...' : _money(_buyerDebt),
                      icon: Icons.credit_card_outlined,
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

                      if (mounted) {
                        await _loadDashboard();
                      }
                    },
                  ),

                  _ActionCard(
                    title: 'Farmers',
                    icon: Icons.agriculture_outlined,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FarmersScreen(),
                        ),
                      );

                      if (mounted) {
                        await _loadDashboard();
                      }
                    },
                  ),

                  _ActionCard(
                    title: 'Buyers',
                    icon: Icons.groups_outlined,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BuyersScreen()),
                      );

                      if (mounted) {
                        await _loadDashboard();
                      }
                    },
                  ),

                  _ActionCard(
                    title: 'Sellers',
                    icon: Icons.person_outline,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SellersScreen(),
                        ),
                      );

                      if (mounted) {
                        await _loadDashboard();
                      }
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

                  _ActionCard(
                    title: 'Expenses',
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OtherExpensesScreen(),
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

// ======================================================================
// DASHBOARD CARD
// ======================================================================

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
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kCardRadius),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 23, color: colorScheme.primary),
            ),

            const SizedBox(height: 14),

            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// FEATURED COMMISSION CARD
// ======================================================================

class _FeaturedDashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _FeaturedDashboardCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kCardRadius),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kCardRadius),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 28, color: colorScheme.primary),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
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

// ======================================================================
// MONEY MOVEMENT TILE
// ======================================================================

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
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kCardRadius),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: colorScheme.primary),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            Text(
              amount,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// QUICK ACTION CARD
// ======================================================================

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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kCardRadius),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kCardRadius),

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
