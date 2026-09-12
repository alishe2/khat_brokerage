import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Same shared radius used on Admin Dashboard
const double _kCardRadius = 16;

enum ReportPeriod { today, yesterday, thisWeek, thisMonth, allTime, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;

  ReportPeriod _selectedPeriod = ReportPeriod.today;

  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // ============================================================
  // BUSINESS DATA (Matching Admin Dashboard metrics)
  // ============================================================

  int _kiloSold = 0;
  double _commission = 0;
  double _buyerPaid = 0;
  double _buyerUnpaid = 0;
  double _paidFromOldDebt = 0;
  double _totalPaid = 0;

  double _farmerWithdrawals = 0;
  double _workerFees = 0;
  double _otherExpenses = 0;

  // Null means worker fees were not recorded for this period
  double? _adminProfit;

  // Overall snapshots (Total Farmer Money & Total Buyer Debt)
  double _farmerMoney = 0;
  double _buyerDebt = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // ============================================================
  // DATE FILTER LOGIC
  // ============================================================

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  ({String? start, String? end}) _getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedPeriod) {
      case ReportPeriod.today:
        final d = _formatDate(today);
        return (start: d, end: d);

      case ReportPeriod.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        final d = _formatDate(yesterday);
        return (start: d, end: d);

      case ReportPeriod.thisWeek:
        final weekday = today.weekday; // 1 = Monday
        final monday = today.subtract(Duration(days: weekday - 1));
        return (start: _formatDate(monday), end: _formatDate(today));

      case ReportPeriod.thisMonth:
        final firstDay = DateTime(today.year, today.month, 1);
        return (start: _formatDate(firstDay), end: _formatDate(today));

      case ReportPeriod.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return (
            start: _formatDate(_customStartDate!),
            end: _formatDate(_customEndDate!),
          );
        }
        final d = _formatDate(today);
        return (start: d, end: d);

      case ReportPeriod.allTime:
        return (start: null, end: null);
    }
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case ReportPeriod.today:
        return 'Today (${_formatDate(DateTime.now())})';
      case ReportPeriod.yesterday:
        final y = DateTime.now().subtract(const Duration(days: 1));
        return 'Yesterday (${_formatDate(y)})';
      case ReportPeriod.thisWeek:
        return 'This Week';
      case ReportPeriod.thisMonth:
        return 'This Month';
      case ReportPeriod.allTime:
        return 'All Time';
      case ReportPeriod.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return '${_formatDate(_customStartDate!)} → ${_formatDate(_customEndDate!)}';
        }
        return 'Custom Range';
    }
  }

  // ============================================================
  // LOAD REPORT DATA
  // ============================================================

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final range = _getDateRange();
      final hasDateFilter = range.start != null && range.end != null;
      final isSingleDate = hasDateFilter && range.start == range.end;

      // 1. Sales query
      var salesQuery = _supabase
          .from('sales')
          .select('total_bundles, commission_amount, sale_date');

      if (hasDateFilter) {
        if (isSingleDate) {
          salesQuery = salesQuery.eq('sale_date', range.start!);
        } else {
          salesQuery = salesQuery
              .gte('sale_date', range.start!)
              .lte('sale_date', range.end!);
        }
      }

      // 2. Buyer payments on sales
      var saleBuyersQuery = _supabase
          .from('sale_buyers')
          .select('paid_amount, unpaid_amount, sales!inner(sale_date)');

      if (hasDateFilter) {
        if (isSingleDate) {
          saleBuyersQuery = saleBuyersQuery.eq('sales.sale_date', range.start!);
        } else {
          saleBuyersQuery = saleBuyersQuery
              .gte('sales.sale_date', range.start!)
              .lte('sales.sale_date', range.end!);
        }
      }

      // 3. Paid from old debt
      var buyerDebtPaymentsQuery = _supabase
          .from('buyer_debt_payments')
          .select('amount, payment_date');

      if (hasDateFilter) {
        if (isSingleDate) {
          buyerDebtPaymentsQuery = buyerDebtPaymentsQuery.eq(
            'payment_date',
            range.start!,
          );
        } else {
          buyerDebtPaymentsQuery = buyerDebtPaymentsQuery
              .gte('payment_date', range.start!)
              .lte('payment_date', range.end!);
        }
      }

      // 4. Overall Farmer Money
      final farmersQuery = _supabase
          .from('farmers')
          .select('current_balance')
          .eq('is_active', true);

      // 5. Overall Buyer Debt
      final buyersQuery = _supabase
          .from('buyers')
          .select('current_debt')
          .eq('is_active', true);

      // 6. Farmer Withdrawals
      var withdrawalsQuery = _supabase
          .from('farmer_withdrawals')
          .select('amount, withdrawal_date');

      if (hasDateFilter) {
        if (isSingleDate) {
          withdrawalsQuery = withdrawalsQuery.eq(
            'withdrawal_date',
            range.start!,
          );
        } else {
          withdrawalsQuery = withdrawalsQuery
              .gte('withdrawal_date', range.start!)
              .lte('withdrawal_date', range.end!);
        }
      }

      // 7. Worker Fees
      var workerFeesQuery = _supabase
          .from('worker_fees')
          .select('amount, fee_date');

      if (hasDateFilter) {
        if (isSingleDate) {
          workerFeesQuery = workerFeesQuery.eq('fee_date', range.start!);
        } else {
          workerFeesQuery = workerFeesQuery
              .gte('fee_date', range.start!)
              .lte('fee_date', range.end!);
        }
      }

      // 8. Other Expenses
      var otherExpensesQuery = _supabase
          .from('other_expenses')
          .select('amount, expense_date');

      if (hasDateFilter) {
        if (isSingleDate) {
          otherExpensesQuery = otherExpensesQuery.eq(
            'expense_date',
            range.start!,
          );
        } else {
          otherExpensesQuery = otherExpensesQuery
              .gte('expense_date', range.start!)
              .lte('expense_date', range.end!);
        }
      }

      // Execute all queries in parallel
      final results = await Future.wait<dynamic>([
        salesQuery,
        saleBuyersQuery,
        buyerDebtPaymentsQuery,
        farmersQuery,
        buyersQuery,
        withdrawalsQuery,
        workerFeesQuery,
        otherExpensesQuery,
      ]);

      final salesData = results[0] as List;
      final saleBuyerData = results[1] as List;
      final oldDebtPaymentsData = results[2] as List;
      final farmersData = results[3] as List;
      final buyersData = results[4] as List;
      final withdrawalsData = results[5] as List;
      final workerFeeData = results[6] as List;
      final otherExpensesData = results[7] as List;

      // --------------------------------------------------------
      // AGGREGATE RESULTS
      // --------------------------------------------------------

      // Sales & Commission
      int kiloSold = 0;
      double commission = 0;
      for (final sale in salesData) {
        kiloSold += (sale['total_bundles'] as num?)?.toInt() ?? 0;
        commission += (sale['commission_amount'] as num?)?.toDouble() ?? 0;
      }

      // Buyer Paid on Sales & Unpaid
      double buyerPaid = 0;
      double buyerUnpaid = 0;
      for (final buyer in saleBuyerData) {
        buyerPaid += (buyer['paid_amount'] as num?)?.toDouble() ?? 0;
        buyerUnpaid += (buyer['unpaid_amount'] as num?)?.toDouble() ?? 0;
      }

      // Paid from Old Debt
      double paidFromOldDebt = 0;
      for (final payment in oldDebtPaymentsData) {
        paidFromOldDebt += (payment['amount'] as num?)?.toDouble() ?? 0;
      }

      final totalPaid = buyerPaid + paidFromOldDebt;

      // Total Farmer Money (all active farmers)
      double farmerMoney = 0;
      for (final farmer in farmersData) {
        farmerMoney += (farmer['current_balance'] as num?)?.toDouble() ?? 0;
      }

      // Total Buyer Debt (all active buyers)
      double buyerDebt = 0;
      for (final buyer in buyersData) {
        buyerDebt += (buyer['current_debt'] as num?)?.toDouble() ?? 0;
      }

      // Farmer Withdrawals
      double farmerWithdrawals = 0;
      for (final withdrawal in withdrawalsData) {
        farmerWithdrawals += (withdrawal['amount'] as num?)?.toDouble() ?? 0;
      }

      // Worker Fees
      double workerFees = 0;
      final bool hasWorkerFeesRecorded = workerFeeData.isNotEmpty;
      for (final fee in workerFeeData) {
        workerFees += (fee['amount'] as num?)?.toDouble() ?? 0;
      }

      // Other Expenses
      double otherExpenses = 0;
      for (final expense in otherExpensesData) {
        otherExpenses += (expense['amount'] as num?)?.toDouble() ?? 0;
      }

      // Admin Profit: Commission - Worker Fees - Other Expenses
      double? adminProfit;
      if (hasWorkerFeesRecorded || workerFees > 0) {
        adminProfit = commission - workerFees - otherExpenses;
      }

      if (!mounted) return;

      setState(() {
        _kiloSold = kiloSold;
        _commission = commission;
        _buyerPaid = buyerPaid;
        _buyerUnpaid = buyerUnpaid;
        _paidFromOldDebt = paidFromOldDebt;
        _totalPaid = totalPaid;

        _farmerMoney = farmerMoney;
        _buyerDebt = buyerDebt;

        _farmerWithdrawals = farmerWithdrawals;
        _workerFees = workerFees;
        _otherExpenses = otherExpenses;

        _adminProfit = adminProfit;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Could not load reports: $e'),
        ),
      );
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = ReportPeriod.custom;
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      await _loadReport();
    }
  }

  String _money(double amount) {
    return '${amount.toStringAsFixed(2)} Birr';
  }

  // ============================================================
  // PERIOD SELECTOR CHIPS
  // ============================================================

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildPeriodChip('Today', ReportPeriod.today),
          const SizedBox(width: 8),
          _buildPeriodChip('Yesterday', ReportPeriod.yesterday),
          const SizedBox(width: 8),
          _buildPeriodChip('This Week', ReportPeriod.thisWeek),
          const SizedBox(width: 8),
          _buildPeriodChip('This Month', ReportPeriod.thisMonth),
          const SizedBox(width: 8),
          _buildPeriodChip('All Time', ReportPeriod.allTime),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(
              _selectedPeriod == ReportPeriod.custom &&
                      _customStartDate != null &&
                      _customEndDate != null
                  ? '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}'
                  : 'Custom Range',
            ),
            backgroundColor: _selectedPeriod == ReportPeriod.custom
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            onPressed: _pickCustomRange,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, ReportPeriod period) {
    final isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = period;
          });
          _loadReport();
        }
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadReport,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Text(
                            _getPeriodLabel(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Business financial performance report',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ==============================================
                          // PERIOD SUMMARY (Identical wrap grid as Admin)
                          // ==============================================
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final cardWidth = (constraints.maxWidth - 12) / 2;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: cardWidth,
                                    child: _ReportDashboardCard(
                                      title: 'Kilo Sold',
                                      value: '$_kiloSold',
                                      icon: Icons.inventory_2_outlined,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _ReportDashboardCard(
                                      title: 'Buyer Paid',
                                      value: _money(_buyerPaid),
                                      icon: Icons.payments_outlined,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _ReportDashboardCard(
                                      title: 'Paid From Old Debt',
                                      value: _money(_paidFromOldDebt),
                                      icon: Icons.history_outlined,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _ReportDashboardCard(
                                      title: 'Buyer Unpaid',
                                      value: _money(_buyerUnpaid),
                                      icon: Icons.money_off_outlined,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _ReportDashboardCard(
                                      title: 'Total Paid',
                                      value: _money(_totalPaid),
                                      icon: Icons.payments_outlined,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _ReportDashboardCard(
                                      title: 'Farmer Withdrawal',
                                      value: _money(_farmerWithdrawals),
                                      icon: Icons.arrow_downward,
                                    ),
                                  ),

                                  // Commission (Featured Card)
                                  SizedBox(
                                    width: constraints.maxWidth,
                                    child: _ReportFeaturedCard(
                                      title: 'Commission',
                                      value: _money(_commission),
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // ==============================================
                          // WORKER FEES, OTHER EXPENSES & ADMIN PROFIT
                          // ==============================================
                          _ReportMoneyMovementTile(
                            title: 'Worker Fees',
                            amount: _adminProfit == null && _workerFees == 0
                                ? 'Not recorded'
                                : _money(_workerFees),
                            icon: Icons.people_outline,
                          ),

                          const SizedBox(height: 10),

                          _ReportMoneyMovementTile(
                            title: 'Other Expenses',
                            amount: _money(_otherExpenses),
                            icon: Icons.receipt_long_outlined,
                          ),

                          const SizedBox(height: 10),

                          _ReportMoneyMovementTile(
                            title: 'Admin Profit',
                            amount: _adminProfit == null
                                ? 'Pending worker fee'
                                : _money(_adminProfit!),
                            icon: Icons.account_balance_outlined,
                            isProfit: true,
                          ),

                          const SizedBox(height: 24),

                          // ==============================================
                          // OVERALL BUSINESS SNAPSHOT
                          // ==============================================
                          const Text(
                            'Overall Business Position',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Current active balances across all accounts',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: _ReportDashboardCard(
                                  title: 'Farmer Money',
                                  value: _money(_farmerMoney),
                                  icon: Icons.agriculture_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ReportDashboardCard(
                                  title: 'Buyer Debt',
                                  value: _money(_buyerDebt),
                                  icon: Icons.credit_card_outlined,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// WIDGETS (Matching visual design and structure of Admin Dashboard)
// ======================================================================

class _ReportDashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReportDashboardCard({
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

class _ReportFeaturedCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReportFeaturedCard({
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

class _ReportMoneyMovementTile extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final bool isProfit;

  const _ReportMoneyMovementTile({
    required this.title,
    required this.amount,
    required this.icon,
    this.isProfit = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kCardRadius),
        side: BorderSide(
          color: isProfit
              ? colorScheme.primary.withValues(alpha: 0.30)
              : colorScheme.outlineVariant,
        ),
      ),
      color: isProfit ? colorScheme.primary.withValues(alpha: 0.04) : null,
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
                  fontWeight: isProfit ? FontWeight.bold : FontWeight.normal,
                  color: isProfit
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isProfit ? colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
