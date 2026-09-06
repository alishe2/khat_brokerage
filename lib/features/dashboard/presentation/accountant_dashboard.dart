import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:khat_brokerage/features/farmers/presentation/farmers_screen.dart';
import 'package:khat_brokerage/features/sales/presentation/record_sale_screen.dart';
import 'package:khat_brokerage/features/buyers/presentation/buyers_screen.dart';
import 'package:khat_brokerage/features/transactions/presentation/transactions_screen.dart';
import 'package:khat_brokerage/features/profile/presentation/accountant_profile_screen.dart';

class AccountantDashboard extends StatefulWidget {
  const AccountantDashboard({super.key});

  @override
  State<AccountantDashboard> createState() => _AccountantDashboardState();
}

class _AccountantDashboardState extends State<AccountantDashboard> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isLoadingPermissions = true;

  int _kiloSoldToday = 0;

  double _buyerPaidToday = 0;
  double _buyerUnpaidToday = 0;

  // ============================================================
  // ACCOUNTANT PERMISSIONS
  // ============================================================

  bool _accountantEnabled = true;

  bool _canManageFarmers = false;
  bool _canManageBuyers = false;
  bool _canRecordSales = false;
  bool _canRecordFarmerWithdrawals = false;
  bool _canRecordBuyerPayments = false;
  bool _canManageSellers = false;
  bool _canViewReports = false;

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
          .select(
            '''
            accountant_enabled,
            can_manage_farmers,
            can_manage_buyers,
            can_record_sales,
            can_record_farmer_withdrawals,
            can_record_buyer_payments,
            can_manage_sellers,
            can_view_reports
            ''',
          )
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        setState(() {
          _accountantEnabled = data['accountant_enabled'] == true;

          _canManageFarmers = data['can_manage_farmers'] == true;
          _canManageBuyers = data['can_manage_buyers'] == true;
          _canRecordSales = data['can_record_sales'] == true;
          _canRecordFarmerWithdrawals =
              data['can_record_farmer_withdrawals'] == true;
          _canRecordBuyerPayments =
              data['can_record_buyer_payments'] == true;
          _canManageSellers = data['can_manage_sellers'] == true;
          _canViewReports = data['can_view_reports'] == true;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load accountant permissions: $e',
          ),
        ),
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
    // Master switch has highest priority.
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

      // ==========================================================
      // TODAY'S SALES
      // ==========================================================

      final salesData = await _supabase
          .from('sales')
          .select('total_bundles')
          .eq('sale_date', todayString);

      int kiloSold = 0;

      for (final sale in salesData) {
        kiloSold +=
            (sale['total_bundles'] as num?)?.toInt() ?? 0;
      }

      // ==========================================================
      // TODAY'S BUYER PAYMENTS
      // ==========================================================

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

      if (!mounted) return;

      setState(() {
        _kiloSoldToday = kiloSold;
        _buyerPaidToday = buyerPaid;
        _buyerUnpaidToday = buyerUnpaid;
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

  // ============================================================
  // REFRESH EVERYTHING
  // ============================================================

  Future<void> _refreshDashboard() async {
    await Future.wait([
      _loadPermissions(),
      _loadDashboard(),
    ]);
  }

  // ============================================================
  // MONEY FORMAT
  // ============================================================

  String _money(double amount) {
    return '${amount.toStringAsFixed(2)} Birr';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accountant Dashboard'),

        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const AccountantProfileScreen(),
                    ),
                  )
                  .then((_) {
                if (mounted) {
                  _refreshDashboard();
                }
              });
            },
            tooltip: 'Account',
            icon: const Icon(
              Icons.account_circle_outlined,
            ),
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
              // HEADER
              // ==================================================

              const Text(
                'Good morning, Accountant',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                _accountantEnabled
                    ? 'Today\'s business activities'
                    : 'Your account access is currently restricted',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // ACCESS RESTRICTED MESSAGE
              // ==================================================

              if (!_isLoadingPermissions &&
                  !_accountantEnabled) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),

                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 30,
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

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
                                  color: Colors.grey.shade600,
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
              // TODAY
              // ==================================================

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
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _DashboardCard(
                      title: 'Buyer Paid',
                      value: _isLoading
                          ? '...'
                          : _money(_buyerPaidToday),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _DashboardCard(
                title: 'Buyer Unpaid',
                value: _isLoading
                    ? '...'
                    : _money(_buyerUnpaidToday),
                icon: Icons.money_off_outlined,
              ),

              const SizedBox(height: 24),

              // ==================================================
              // WORK AREA
              // ==================================================

              const Text(
                'Work Area',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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

                  physics:
                      const NeverScrollableScrollPhysics(),

                  crossAxisSpacing: 12,

                  mainAxisSpacing: 12,

                  childAspectRatio: 1.5,

                  children: [
                    // ==========================================
                    // RECORD SALE
                    // ==========================================

                    _ActionCard(
                      title: 'Record Sale',
                      icon:
                          Icons.point_of_sale_outlined,
                      enabled:
                          _isAllowed(_canRecordSales),

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

                    // ==========================================
                    // FARMERS
                    // ==========================================

                    _ActionCard(
                      title: 'Farmers',
                      icon:
                          Icons.agriculture_outlined,
                      enabled:
                          _isAllowed(_canManageFarmers),

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

                    // ==========================================
                    // BUYERS
                    // ==========================================

                    _ActionCard(
                      title: 'Buyers',
                      icon:
                          Icons.groups_outlined,
                      enabled:
                          _isAllowed(_canManageBuyers),

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

                    // ==========================================
                    // TRANSACTIONS
                    // ==========================================

                    _ActionCard(
                      title: 'Transactions',
                      icon:
                          Icons.receipt_long_outlined,

                      // Transactions currently has no
                      // accountant permission field.
                      enabled: true,

                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const TransactionsScreen(),
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
// QUICK ACTION CARD
// ==================================================================

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
      child: InkWell(
        onTap: enabled ? onTap : null,

        borderRadius:
            BorderRadius.circular(12),

        child: Opacity(
          opacity: enabled ? 1.0 : 0.45,

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              Icon(
                enabled
                    ? icon
                    : Icons.lock_outline,
                size: 32,
              ),

              const SizedBox(height: 8),

              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),

              if (!enabled) ...[
                const SizedBox(height: 4),

                const Text(
                  'Restricted',
                  style: TextStyle(
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}