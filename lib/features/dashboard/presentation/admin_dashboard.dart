import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:khat_brokerage/core/localization/app_strings.dart';
import 'package:khat_brokerage/features/farmers/presentation/farmers_screen.dart';
import 'package:khat_brokerage/features/sales/presentation/record_sale_screen.dart';
import 'package:khat_brokerage/features/buyers/presentation/buyers_screen.dart';
import 'package:khat_brokerage/features/sellers/presentation/sellers_screen.dart';
import 'package:khat_brokerage/features/accountant/presentation/accountant_screen.dart';
import 'package:khat_brokerage/features/transactions/presentation/transactions_screen.dart';
import 'package:khat_brokerage/features/reports/presentation/reports_screen.dart';
import 'package:khat_brokerage/features/profile/presentation/admin_profile_screen.dart';
import 'package:khat_brokerage/features/expenses/presentation/other_expenses_screen.dart';

const double _kCardRadius = 16;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;

  String _adminName = '';

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
            .from('farmers')
            .select('current_balance')
            .eq('is_active', true),

        _supabase.from('buyers').select('current_debt').eq('is_active', true),

        _supabase
            .from('farmer_withdrawals')
            .select('amount')
            .eq('withdrawal_date', todayString),

        _supabase
            .from('worker_fees')
            .select('amount')
            .eq('fee_date', todayString)
            .maybeSingle(),

        _supabase
            .from('other_expenses')
            .select('amount')
            .eq('expense_date', todayString),
      ]);

      final userData = results[0] as Map<String, dynamic>?;
      final salesData = results[1] as List;
      final saleBuyerData = results[2] as List;
      final oldDebtPaymentsData = results[3] as List;
      final farmersData = results[4] as List;
      final buyersData = results[5] as List;
      final withdrawalsData = results[6] as List;
      final workerFeeData = results[7] as Map<String, dynamic>?;
      final otherExpensesData = results[8] as List;

      String adminName = '';

      if (userId != null) {
        adminName = userData?['full_name']?.toString().trim() ?? '';
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

      double farmerMoney = 0;

      for (final farmer in farmersData) {
        farmerMoney += (farmer['current_balance'] as num?)?.toDouble() ?? 0;
      }

      double buyerDebt = 0;

      for (final buyer in buyersData) {
        buyerDebt += (buyer['current_debt'] as num?)?.toDouble() ?? 0;
      }

      double farmerWithdrawals = 0;

      for (final withdrawal in withdrawalsData) {
        farmerWithdrawals += (withdrawal['amount'] as num?)?.toDouble() ?? 0;
      }

      double? workerFees;

      if (workerFeeData != null) {
        workerFees = (workerFeeData['amount'] as num?)?.toDouble() ?? 0;
      }

      double otherExpenses = 0;

      for (final expense in otherExpensesData) {
        otherExpenses += (expense['amount'] as num?)?.toDouble() ?? 0;
      }

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
      ).showSnackBar(SnackBar(content: Text(S.errLoadingData(e.toString()))));
    }
  }

  String _money(double amount) {
    return '${amount.toStringAsFixed(2)} ${S.birr}';
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild automatically when the language is changed
    return ValueListenableBuilder<String>(
      valueListenable: S.currentLocale,
      builder: (context, currentLang, _) {
        final displayName = _adminName.isNotEmpty ? _adminName : S.admin;
        final greeting = S.isOromo
            ? 'Baga nagaan dhufte, $displayName'
            : 'Welcome, $displayName';

        return Scaffold(
          appBar: AppBar(
            title: Text(S.adminDashboard),
            actions: [
              // ======================================================
              // LANGUAGE SWITCHER BUTTON
              // ======================================================
              PopupMenuButton<String>(
                tooltip: S.language,
                icon: const Icon(Icons.language_outlined),
                onSelected: (String langCode) async {
                  await S.setLanguage(langCode);
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'om',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          color: S.isOromo
                              ? Colors.green.shade700
                              : Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Afaan Oromoo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'en',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          color: !S.isOromo
                              ? Colors.green.shade700
                              : Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'English',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Profile Screen
              IconButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdminProfileScreen(),
                    ),
                  );

                  if (mounted) {
                    await _loadDashboard();
                  }
                },
                tooltip: S.isOromo ? 'Herreega' : 'Profile',
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
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    S.todaysOverview,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // TODAY (Har'a)
                  // ==================================================
                  Text(
                    S.today,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
                              title: S.kiloSold,
                              value: _isLoading ? '...' : '$_kiloSoldToday',
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),

                          SizedBox(
                            width: cardWidth,
                            child: _DashboardCard(
                              title: S.buyerPaid,
                              value: _isLoading
                                  ? '...'
                                  : _money(_buyerPaidToday),
                              icon: Icons.payments_outlined,
                            ),
                          ),

                          SizedBox(
                            width: cardWidth,
                            child: _DashboardCard(
                              title: S.paidFromOldDebt,
                              value: _isLoading
                                  ? '...'
                                  : _money(_paidFromOldDebtToday),
                              icon: Icons.history_outlined,
                            ),
                          ),

                          SizedBox(
                            width: cardWidth,
                            child: _DashboardCard(
                              title: S.buyerUnpaid,
                              value: _isLoading
                                  ? '...'
                                  : _money(_buyerUnpaidToday),
                              icon: Icons.money_off_outlined,
                            ),
                          ),

                          SizedBox(
                            width: cardWidth,
                            child: _DashboardCard(
                              title: S.totalPaid,
                              value: _isLoading
                                  ? '...'
                                  : _money(_totalPaidToday),
                              icon: Icons.payments_outlined,
                            ),
                          ),

                          SizedBox(
                            width: cardWidth,
                            child: _DashboardCard(
                              title: S.farmerWithdrawal,
                              value: _isLoading
                                  ? '...'
                                  : _money(_farmerWithdrawalsToday),
                              icon: Icons.arrow_downward,
                            ),
                          ),

                          SizedBox(
                            width: constraints.maxWidth,
                            child: _FeaturedDashboardCard(
                              title: S.commission,
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

                  // ==================================================
                  // EXPENSES & PROFIT
                  // ==================================================
                  _MoneyMovementTile(
                    title: S.workerFees,
                    amount: _isLoading
                        ? '...'
                        : _adminProfitToday == null
                        ? S.notRecorded
                        : _money(_workerFeesToday),
                    icon: Icons.people_outline,
                  ),

                  const SizedBox(height: 10),

                  _MoneyMovementTile(
                    title: S.otherExpenses,
                    amount: _isLoading ? '...' : _money(_otherExpensesToday),
                    icon: Icons.receipt_long_outlined,
                  ),

                  const SizedBox(height: 10),

                  _MoneyMovementTile(
                    title: S.adminProfit,
                    amount: _isLoading
                        ? '...'
                        : _adminProfitToday == null
                        ? S.pendingStatus
                        : _money(_adminProfitToday!),
                    icon: Icons.account_balance_outlined,
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // OVERALL BUSINESS (Waliigala Haala Hojii)
                  // ==================================================
                  Text(
                    S.overallBusiness,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _DashboardCard(
                          title: S.farmerMoney,
                          value: _isLoading ? '...' : _money(_farmerMoney),
                          icon: Icons.agriculture_outlined,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: _DashboardCard(
                          title: S.buyerDebt,
                          value: _isLoading ? '...' : _money(_buyerDebt),
                          icon: Icons.credit_card_outlined,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // QUICK ACTIONS (Tajaajiloota Ariifachiisoo)
                  // ==================================================
                  Text(
                    S.quickActions,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
                        title: S.recordSale,
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
                        title: S.farmers,
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
                        title: S.buyers,
                        icon: Icons.groups_outlined,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BuyersScreen(),
                            ),
                          );

                          if (mounted) {
                            await _loadDashboard();
                          }
                        },
                      ),

                      _ActionCard(
                        title: S.sellers,
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
                        title: S.accountant,
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
                        title: S.transactions,
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
                        title: S.reports,
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
                        title: S.expenses,
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
      },
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
