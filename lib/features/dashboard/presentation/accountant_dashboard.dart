import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:khat_brokerage/features/farmers/presentation/farmers_screen.dart';
import 'package:khat_brokerage/features/sales/presentation/record_sale_screen.dart';
import 'package:khat_brokerage/features/buyers/presentation/buyers_screen.dart';
import 'package:khat_brokerage/features/sellers/presentation/sellers_screen.dart';
import 'package:khat_brokerage/features/transactions/presentation/transactions_screen.dart';
import 'package:khat_brokerage/features/reports/presentation/reports_screen.dart';
import 'package:khat_brokerage/features/expenses/presentation/other_expenses_screen.dart';
import 'package:khat_brokerage/features/profile/presentation/accountant_profile_screen.dart';

// Same shared radius used on the Admin dashboard, so both screens
// read as one visual family instead of two different apps.
const double _kCardRadius = 16;

class AccountantDashboard extends StatefulWidget {
  const AccountantDashboard({super.key});

  @override
  State<AccountantDashboard> createState() => _AccountantDashboardState();
}

class _AccountantDashboardState extends State<AccountantDashboard> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isLoadingPermissions = true;

  String _accountantName = 'Accountant';

  // ============================================================
  // DASHBOARD DATA — all seven figures, matching Admin's set
  // ============================================================

  int _kiloSoldToday = 0;

  double _commissionToday = 0;
  double _buyerPaidToday = 0;
  double _buyerUnpaidToday = 0;
  double _paidFromOldDebtToday = 0;
  double _totalPaidToday = 0;
  double _farmerWithdrawalsToday = 0;

  // ============================================================
  // ACCOUNTANT ACCESS
  // ============================================================

  bool _accountantEnabled = true;

  bool _showDashboard = true;
  bool _showRecordSale = true;
  bool _showFarmers = true;
  bool _showBuyers = true;
  bool _showSellers = true;
  bool _showTransactions = true;
  bool _showReports = true;
  bool _showExpenses = true;

  @override
  void initState() {
    super.initState();

    _loadPermissions();
    _loadDashboard();
  }

  // ============================================================
  // LOAD ACCOUNTANT PERMISSIONS
  // ============================================================

  Future<void> _loadPermissions() async {
    if (mounted) {
      setState(() {
        _isLoadingPermissions = true;
      });
    }

    try {
      final data = await _supabase
          .from('accountant_permissions')
          .select('''
            accountant_enabled,
            show_dashboard_to_accountant,
            show_record_sale_to_accountant,
            show_farmers_to_accountant,
            show_buyers_to_accountant,
            show_sellers_to_accountant,
            show_transactions_to_accountant,
            show_reports_to_accountant,
            show_expenses_to_accountant
            ''')
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        setState(() {
          _accountantEnabled = data['accountant_enabled'] as bool? ?? true;

          _showDashboard =
              data['show_dashboard_to_accountant'] as bool? ?? true;

          _showRecordSale =
              data['show_record_sale_to_accountant'] as bool? ?? true;

          _showFarmers = data['show_farmers_to_accountant'] as bool? ?? true;

          _showBuyers = data['show_buyers_to_accountant'] as bool? ?? true;

          _showSellers = data['show_sellers_to_accountant'] as bool? ?? true;

          _showTransactions =
              data['show_transactions_to_accountant'] as bool? ?? true;

          _showReports = data['show_reports_to_accountant'] as bool? ?? true;

          _showExpenses = data['show_expenses_to_accountant'] as bool? ?? true;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load accountant permissions: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPermissions = false;
        });
      }
    }
  }

  // ============================================================
  // CHECK WHETHER A FEATURE IS ALLOWED
  // ============================================================

  bool _isAllowed(bool individualPermission) {
    if (!_accountantEnabled) {
      return false;
    }

    return individualPermission;
  }

  // ============================================================
  // LOAD ACCOUNTANT DASHBOARD
  // ============================================================

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

      final results = await Future.wait<dynamic>([
        userId != null
            ? _supabase
                  .from('users')
                  .select('full_name')
                  .eq('id', userId)
                  .maybeSingle()
            : Future.value(null),

        _supabase
            .from('sales')
            .select('total_bundles, commission_amount')
            .eq('sale_date', todayString),

        _supabase
            .from('sale_buyers')
            .select('paid_amount, unpaid_amount, sales!inner(sale_date)')
            .eq('sales.sale_date', todayString),

        _supabase
            .from('buyer_debt_payments')
            .select('amount')
            .eq('payment_date', todayString),

        _supabase
            .from('farmer_withdrawals')
            .select('amount')
            .eq('withdrawal_date', todayString),
      ]);

      final userData = results[0] as Map<String, dynamic>?;
      final salesData = results[1] as List;
      final saleBuyerData = results[2] as List;
      final oldDebtPaymentsData = results[3] as List;
      final withdrawalsData = results[4] as List;

      String accountantName = 'Accountant';

      if (userId != null) {
        accountantName = userData?['full_name']?.toString().trim() ?? '';

        if (accountantName.isEmpty) {
          accountantName = 'Accountant';
        }
      }

      int kiloSold = 0;
      double commission = 0;

      for (final sale in salesData) {
        kiloSold += (sale['total_bundles'] as num?)?.toInt() ?? 0;
        commission += (sale['commission_amount'] as num?)?.toDouble() ?? 0;
      }

      double buyerPaid = 0;
      double buyerUnpaid = 0;

      for (final buyer in saleBuyerData) {
        buyerPaid += (buyer['paid_amount'] as num?)?.toDouble() ?? 0;
        buyerUnpaid += (buyer['unpaid_amount'] as num?)?.toDouble() ?? 0;
      }

      double paidFromOldDebt = 0;

      for (final payment in oldDebtPaymentsData) {
        paidFromOldDebt += (payment['amount'] as num?)?.toDouble() ?? 0;
      }

      final totalPaid = buyerPaid + paidFromOldDebt;

      double farmerWithdrawals = 0;

      for (final withdrawal in withdrawalsData) {
        farmerWithdrawals += (withdrawal['amount'] as num?)?.toDouble() ?? 0;
      }

      if (!mounted) return;

      setState(() {
        _accountantName = accountantName;

        _kiloSoldToday = kiloSold;
        _commissionToday = commission;
        _buyerPaidToday = buyerPaid;
        _buyerUnpaidToday = buyerUnpaid;
        _paidFromOldDebtToday = paidFromOldDebt;
        _totalPaidToday = totalPaid;
        _farmerWithdrawalsToday = farmerWithdrawals;
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

  Future<void> _refreshDashboard() async {
    await Future.wait([_loadPermissions(), _loadDashboard()]);
  }

  String _money(double amount) {
    return '${amount.toStringAsFixed(2)} Birr';
  }

  Future<void> _openRecordSale() async {
    if (!_isAllowed(_showRecordSale)) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RecordSaleScreen()));

    if (mounted) {
      await _refreshDashboard();
    }
  }

  Future<void> _openFarmers() async {
    if (!_isAllowed(_showFarmers)) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FarmersScreen()));

    if (mounted) {
      await _refreshDashboard();
    }
  }

  Future<void> _openBuyers() async {
    if (!_isAllowed(_showBuyers)) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BuyersScreen()));

    if (mounted) {
      await _refreshDashboard();
    }
  }

  Future<void> _openSellers() async {
    if (!_isAllowed(_showSellers)) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SellersScreen()));

    if (mounted) {
      await _refreshDashboard();
    }
  }

  Future<void> _openTransactions() async {
    if (!_isAllowed(_showTransactions)) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TransactionsScreen()));

    if (mounted) {
      await _refreshDashboard();
    }
  }

  Future<void> _openReports() async {
    if (!_isAllowed(_showReports)) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ReportsScreen()));

    if (mounted) {
      await _refreshDashboard();
    }
  }

  Future<void> _openExpenses() async {
    if (!_isAllowed(_showExpenses)) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OtherExpensesScreen()));

    if (mounted) {
      await _refreshDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dashboardAllowed = _isAllowed(_showDashboard);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accountant Dashboard'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => const AccountantProfileScreen(),
                    ),
                  )
                  .then((_) {
                    if (mounted) {
                      _refreshDashboard();
                    }
                  });
            },
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _refreshDashboard,

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ==================================================
              // HEADER — same style/weight as Admin's
              // ==================================================
              Text(
                'Good morning, $_accountantName',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                !_accountantEnabled
                    ? 'Your account access is currently restricted'
                    : !dashboardAllowed
                    ? 'Dashboard access is restricted'
                    : 'Today\'s business activities',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // ACCOUNT ACCESS RESTRICTED
              // ==================================================
              if (!_isLoadingPermissions && !_accountantEnabled) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kCardRadius),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),

                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 30),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              const Text(
                                'Account access restricted',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                'The administrator has temporarily '
                                'restricted your access to the system.',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],

              // ==================================================
              // TODAY — same LayoutBuilder + Wrap grid as Admin,
              // with Commission featured full-width, instead of
              // the old fixed Row/Expanded pairs.
              // ==================================================
              if (!_isLoadingPermissions && dashboardAllowed) ...[
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
                            value: _isLoading
                                ? '...'
                                : _money(_buyerPaidToday),
                            icon: Icons.payments_outlined,
                          ),
                        ),

                        SizedBox(
                          width: cardWidth,
                          child: _DashboardCard(
                            title: 'Buyer Unpaid',
                            value: _isLoading
                                ? '...'
                                : _money(_buyerUnpaidToday),
                            icon: Icons.money_off_outlined,
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
                            title: 'Total Paid',
                            value: _isLoading
                                ? '...'
                                : _money(_totalPaidToday),
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

                        SizedBox(
                          width: constraints.maxWidth,
                          child: _FeaturedDashboardCard(
                            title: 'Commission',
                            value: _isLoading
                                ? '...'
                                : _money(_commissionToday),
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),
              ],

              // ==================================================
              // DASHBOARD RESTRICTED
              // ==================================================
              if (!_isLoadingPermissions &&
                  _accountantEnabled &&
                  !dashboardAllowed) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kCardRadius),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),

                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.dashboard_outlined,
                            color: Colors.orange,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dashboard restricted',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'The administrator has disabled '
                                'your dashboard access.',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],

              // ==================================================
              // WORK AREA
              // ==================================================
              const Text(
                'Work Area',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              if (_isLoadingPermissions)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
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
                      enabled: _isAllowed(_showRecordSale),
                      onTap: _openRecordSale,
                    ),

                    _ActionCard(
                      title: 'Farmers',
                      icon: Icons.agriculture_outlined,
                      enabled: _isAllowed(_showFarmers),
                      onTap: _openFarmers,
                    ),

                    _ActionCard(
                      title: 'Buyers',
                      icon: Icons.groups_outlined,
                      enabled: _isAllowed(_showBuyers),
                      onTap: _openBuyers,
                    ),

                    _ActionCard(
                      title: 'Sellers',
                      icon: Icons.person_outline,
                      enabled: _isAllowed(_showSellers),
                      onTap: _openSellers,
                    ),

                    _ActionCard(
                      title: 'Transactions',
                      icon: Icons.receipt_long_outlined,
                      enabled: _isAllowed(_showTransactions),
                      onTap: _openTransactions,
                    ),

                    _ActionCard(
                      title: 'Reports',
                      icon: Icons.bar_chart_outlined,
                      enabled: _isAllowed(_showReports),
                      onTap: _openReports,
                    ),

                    _ActionCard(
                      title: 'Expenses',
                      icon: Icons.account_balance_wallet_outlined,
                      enabled: _isAllowed(_showExpenses),
                      onTap: _openExpenses,
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
// DASHBOARD CARD — identical structure/styling to Admin's version
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
// FEATURED COMMISSION CARD — identical to Admin's version
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
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.10)),
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
// QUICK ACTION CARD — same border/radius as Admin's, plus the
// enabled/disabled + "Restricted" treatment unique to this screen.
// ======================================================================

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.enabled,
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
        onTap: enabled ? onTap : null,

        borderRadius: BorderRadius.circular(_kCardRadius),

        child: Opacity(
          opacity: enabled ? 1.0 : 0.45,

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Icon(enabled ? icon : Icons.lock_outline, size: 32),

              const SizedBox(height: 8),

              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),

              if (!enabled) ...[
                const SizedBox(height: 4),

                const Text('Restricted', style: TextStyle(fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}