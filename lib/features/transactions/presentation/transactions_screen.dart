import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:khat_brokerage/features/sales/presentation/edit_sale_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  List<Map<String, dynamic>> _transactions = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD ALL TRANSACTIONS
  // ============================================================

  Future<void> _loadTransactions() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // ==========================================================
      // LOAD TRANSACTION TABLES
      // ==========================================================

      final sales = await _supabase
          .from('sales')
          .select(
            'id, '
            'transaction_code, '
            'farmer_id, '
            'seller_id, '
            'sale_date, '
            'total_bundles, '
            'total_sales, '
            'commission_amount, '
            'advance_loan, '
            'farmer_amount, '
            'created_at',
          )
          .order('created_at', ascending: false);

      final withdrawals = await _supabase
          .from('farmer_withdrawals')
          .select(
            'id, '
            'farmer_id, '
            'amount, '
            'withdrawal_date, '
            'created_at',
          )
          .order('created_at', ascending: false);

      final buyerPayments = await _supabase
          .from('buyer_debt_payments')
          .select(
            'id, '
            'buyer_id, '
            'amount, '
            'payment_date, '
            'recorded_by, '
            'created_at',
          )
          .order('created_at', ascending: false);

      final buyerAdjustments = await _supabase
          .from('buyer_debt_adjustments')
          .select(
            'id, '
            'buyer_id, '
            'old_balance, '
            'new_balance, '
            'reason, '
            'adjusted_by, '
            'created_at',
          )
          .order('created_at', ascending: false);

      final farmerAdjustments = await _supabase
          .from('farmer_balance_adjustments')
          .select(
            'id, '
            'farmer_id, '
            'old_balance, '
            'new_balance, '
            'reason, '
            'adjusted_by, '
            'created_at',
          )
          .order('created_at', ascending: false);

      // ==========================================================
      // LOAD FARMERS
      // ==========================================================

      final farmers = await _supabase.from('farmers').select('id, full_name');

      final Map<String, String> farmerNames = {
        for (final farmer in farmers)
          farmer['id'].toString():
              farmer['full_name']?.toString() ?? 'Unknown Farmer',
      };

      // ==========================================================
      // LOAD BUYERS
      // ==========================================================

      final buyers = await _supabase.from('buyers').select('id, group_name');

      final Map<String, String> buyerNames = {
        for (final buyer in buyers)
          buyer['id'].toString():
              buyer['group_name']?.toString() ?? 'Unknown Buyer',
      };

      // ==========================================================
      // LOAD SELLERS
      // ==========================================================

      final sellers = await _supabase.from('sellers').select('id, full_name');

      final Map<String, String> sellerNames = {
        for (final seller in sellers)
          seller['id'].toString():
              seller['full_name']?.toString() ?? 'Unknown Seller',
      };

      // ==========================================================
      // COMBINED TRANSACTIONS
      // ==========================================================

      final List<Map<String, dynamic>> combined = [];

      // ==========================================================
      // SALES
      // ==========================================================

      for (final sale in sales) {
        final farmerId = sale['farmer_id']?.toString();
        final sellerId = sale['seller_id']?.toString();

        final farmerName = farmerNames[farmerId] ?? 'Unknown Farmer';

        final sellerName = sellerNames[sellerId] ?? 'Unknown Seller';

        combined.add({
          'id': sale['id'],
          'type': 'Sale',
          'code': sale['transaction_code'],
          'date': sale['sale_date'],
          'amount': sale['total_sales'] ?? 0,

          // Keep previous information.
          'details': '${sale['total_bundles'] ?? 0} kilo',

          // Additional information.
          'farmer_name': farmerName,
          'seller_name': sellerName,

          'created_at': sale['created_at'],

          'farmer_id': sale['farmer_id'],
          'seller_id': sale['seller_id'],
          'total_bundles': sale['total_bundles'] ?? 0,
          'total_sales': sale['total_sales'] ?? 0,
          'commission_amount': sale['commission_amount'] ?? 0,
          'advance_loan': sale['advance_loan'] ?? 0,
          'farmer_amount': sale['farmer_amount'] ?? 0,
        });
      }

      // ==========================================================
      // FARMER WITHDRAWALS
      // ==========================================================

      for (final withdrawal in withdrawals) {
        final farmerId = withdrawal['farmer_id']?.toString();

        final farmerName = farmerNames[farmerId] ?? 'Unknown Farmer';

        combined.add({
          'id': withdrawal['id'],
          'type': 'Farmer Withdrawal',
          'code': 'Withdrawal',
          'date': withdrawal['withdrawal_date'],
          'amount': withdrawal['amount'] ?? 0,

          // Keep previous information.
          'details': 'Farmer withdrawal',

          // Additional information.
          'farmer_name': farmerName,

          'created_at': withdrawal['created_at'],
          'farmer_id': withdrawal['farmer_id'],
        });
      }

      // ==========================================================
      // BUYER DEBT PAYMENTS
      // ==========================================================

      for (final payment in buyerPayments) {
        final buyerId = payment['buyer_id']?.toString();

        final buyerName = buyerNames[buyerId] ?? 'Unknown Buyer';

        combined.add({
          'id': payment['id'],
          'type': 'Buyer Payment',
          'code': 'Payment',
          'date': payment['payment_date'],
          'amount': payment['amount'] ?? 0,

          // Keep previous information.
          'details': 'Buyer debt payment',

          // Additional information.
          'buyer_name': buyerName,

          'created_at': payment['created_at'],
          'buyer_id': payment['buyer_id'],
          'recorded_by': payment['recorded_by'],
        });
      }

      // ==========================================================
      // BUYER DEBT ADJUSTMENTS
      // ==========================================================

      for (final adjustment in buyerAdjustments) {
        final oldBalance = adjustment['old_balance'] ?? 0;
        final newBalance = adjustment['new_balance'] ?? 0;

        final difference =
            (double.tryParse(newBalance.toString()) ?? 0) -
            (double.tryParse(oldBalance.toString()) ?? 0);

        final buyerId = adjustment['buyer_id']?.toString();

        final buyerName = buyerNames[buyerId] ?? 'Unknown Buyer';

        combined.add({
          'id': adjustment['id'],
          'type': 'Debt Adjustment',
          'code': 'Debt Adjustment',
          'date': adjustment['created_at'],
          'amount': difference,

          // Keep previous information.
          'details': adjustment['reason'] ?? 'Buyer debt adjustment',

          // Additional information.
          'buyer_name': buyerName,

          'created_at': adjustment['created_at'],

          'buyer_id': adjustment['buyer_id'],
          'old_balance': oldBalance,
          'new_balance': newBalance,
          'reason': adjustment['reason'] ?? '',
          'adjusted_by': adjustment['adjusted_by'],
        });
      }

      // ==========================================================
      // FARMER BALANCE ADJUSTMENTS
      // ==========================================================

      for (final adjustment in farmerAdjustments) {
        final oldBalance = adjustment['old_balance'] ?? 0;
        final newBalance = adjustment['new_balance'] ?? 0;

        final difference =
            (double.tryParse(newBalance.toString()) ?? 0) -
            (double.tryParse(oldBalance.toString()) ?? 0);

        final farmerId = adjustment['farmer_id']?.toString();

        final farmerName = farmerNames[farmerId] ?? 'Unknown Farmer';

        combined.add({
          'id': adjustment['id'],
          'type': 'Farmer Balance Adjustment',
          'code': 'Balance Adjustment',
          'date': adjustment['created_at'],
          'amount': difference,

          // Keep previous information.
          'details': adjustment['reason'] ?? 'Farmer balance adjustment',

          // Additional information.
          'farmer_name': farmerName,

          'created_at': adjustment['created_at'],

          'farmer_id': adjustment['farmer_id'],
          'old_balance': oldBalance,
          'new_balance': newBalance,
          'reason': adjustment['reason'] ?? '',
          'adjusted_by': adjustment['adjusted_by'],
        });
      }

      // ==========================================================
      // SORT EVERYTHING TOGETHER
      // ==========================================================

      combined.sort((a, b) {
        final aDate =
            DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime(2000);

        final bDate =
            DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime(2000);

        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        _transactions = combined;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load transactions: $e')),
      );
    }
  }

  // ============================================================
  // FILTER + SEARCH
  // ============================================================

  List<Map<String, dynamic>> get _filteredTransactions {
    return _transactions.where((transaction) {
      final type = transaction['type']?.toString() ?? '';

      final code = transaction['code']?.toString() ?? '';

      final details = transaction['details']?.toString() ?? '';

      final date = transaction['date']?.toString() ?? '';

      final farmerName = transaction['farmer_name']?.toString() ?? '';

      final sellerName = transaction['seller_name']?.toString() ?? '';

      final buyerName = transaction['buyer_name']?.toString() ?? '';

      final query = _searchQuery.trim().toLowerCase();

      final matchesFilter = _selectedFilter == 'All' || type == _selectedFilter;

      if (!matchesFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return code.toLowerCase().contains(query) ||
          details.toLowerCase().contains(query) ||
          date.toLowerCase().contains(query) ||
          type.toLowerCase().contains(query) ||
          farmerName.toLowerCase().contains(query) ||
          sellerName.toLowerCase().contains(query) ||
          buyerName.toLowerCase().contains(query);
    }).toList();
  }

  // ============================================================
  // ICON
  // ============================================================

  IconData _transactionIcon(String type) {
    switch (type) {
      case 'Sale':
        return Icons.receipt_long_outlined;

      case 'Farmer Withdrawal':
        return Icons.arrow_downward;

      case 'Buyer Payment':
        return Icons.arrow_upward;

      case 'Debt Adjustment':
        return Icons.tune_outlined;

      case 'Farmer Balance Adjustment':
        return Icons.account_balance_wallet_outlined;

      default:
        return Icons.swap_horiz_outlined;
    }
  }

  // ============================================================
  // AMOUNT FORMAT
  // ============================================================

  String _formatAmount(dynamic value) {
    final amount = double.tryParse(value.toString()) ?? 0;

    return '${amount.toStringAsFixed(2)} Birr';
  }

  // ============================================================
  // SALE DETAILS
  // ============================================================

  Future<void> _showSaleDetails(Map<String, dynamic> transaction) async {
    final saleId = transaction['id']?.toString();

    if (saleId == null || saleId.isEmpty) {
      return;
    }

    // ============================================================
    // LOAD THE COMPLETE SALE RECORD
    // ============================================================

    try {
      final saleBuyersData = await _supabase
          .from('sale_buyers')
          .select(
            'id, buyer_id, total_amount, paid_amount, unpaid_amount, created_at',
          )
          .eq('sale_id', saleId)
          .order('created_at');

      final saleBuyers = List<Map<String, dynamic>>.from(saleBuyersData);

      final buyerIds = saleBuyers
          .map((row) => row['buyer_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      final Map<String, String> buyerNames = {};

      if (buyerIds.isNotEmpty) {
        final buyersData = await _supabase
            .from('buyers')
            .select('id, group_name, is_magala')
            .inFilter('id', buyerIds);

        for (final buyer in buyersData) {
          final id = buyer['id']?.toString();
          if (id == null) continue;

          final isMagala = buyer['is_magala'] == true;
          buyerNames[id] = isMagala
              ? 'Magala'
              : (buyer['group_name']?.toString().trim().isNotEmpty == true
                    ? buyer['group_name'].toString()
                    : 'Unknown Buyer');
        }
      }

      final saleBuyerIds = saleBuyers
          .map((row) => row['id'])
          .where((id) => id != null)
          .toList();

      final Map<String, List<Map<String, dynamic>>> priceLinesBySaleBuyer = {};

      if (saleBuyerIds.isNotEmpty) {
        final priceLinesData = await _supabase
            .from('sale_price_lines')
            .select(
              'id, sale_buyer_id, bundle_count, price_per_bundle, line_total',
            )
            .inFilter('sale_buyer_id', saleBuyerIds)
            .order('id');

        for (final line in priceLinesData) {
          final saleBuyerId = line['sale_buyer_id']?.toString();
          if (saleBuyerId == null) continue;

          priceLinesBySaleBuyer
              .putIfAbsent(saleBuyerId, () => [])
              .add(Map<String, dynamic>.from(line));
        }
      }

      if (!mounted) return;

      final totalSales =
          double.tryParse(transaction['total_sales']?.toString() ?? '0') ?? 0;

      final commission =
          double.tryParse(
            transaction['commission_amount']?.toString() ?? '0',
          ) ??
          0;

      final advanceLoan =
          double.tryParse(transaction['advance_loan']?.toString() ?? '0') ?? 0;

      final farmerAmount =
          double.tryParse(transaction['farmer_amount']?.toString() ?? '0') ?? 0;

      final bundles = transaction['total_bundles'] ?? 0;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.82,
              minChildSize: 0.55,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sale Details',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        transaction['code']?.toString() ??
                            'No transaction code',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),

                      const SizedBox(height: 16),

                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            // ==================================================
                            // MAIN SALE INFORMATION
                            // ==================================================
                            _DetailRow(
                              label: 'Farmer',
                              value:
                                  transaction['farmer_name']?.toString() ??
                                  'Unknown Farmer',
                              bold: true,
                            ),

                            _DetailRow(
                              label: 'Seller',
                              value:
                                  transaction['seller_name']?.toString() ??
                                  'Unknown Seller',
                            ),

                            _DetailRow(
                              label: 'Date',
                              value: transaction['date']?.toString() ?? '-',
                            ),

                            _DetailRow(
                              label: 'Kilo Sold',
                              value: '$bundles kilo',
                            ),

                            const Divider(height: 28),

                            // ==================================================
                            // COMPLETE BUYER ENTRIES
                            // ==================================================
                            const Text(
                              'Buyer Entries',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 10),

                            if (saleBuyers.isEmpty)
                              Text(
                                'No buyer entries found for this sale.',
                                style: TextStyle(color: Colors.grey.shade600),
                              )
                            else
                              ...saleBuyers.asMap().entries.map((entry) {
                                final index = entry.key;
                                final saleBuyer = entry.value;
                                final saleBuyerId =
                                    saleBuyer['id']?.toString() ?? '';
                                final buyerId = saleBuyer['buyer_id']
                                    ?.toString();

                                final buyerName = buyerId == null
                                    ? 'Unknown Buyer'
                                    : buyerNames[buyerId] ?? 'Unknown Buyer';

                                final buyerTotal =
                                    double.tryParse(
                                      saleBuyer['total_amount']?.toString() ??
                                          '0',
                                    ) ??
                                    0;

                                final paid =
                                    double.tryParse(
                                      saleBuyer['paid_amount']?.toString() ??
                                          '0',
                                    ) ??
                                    0;

                                final unpaid =
                                    double.tryParse(
                                      saleBuyer['unpaid_amount']?.toString() ??
                                          '0',
                                    ) ??
                                    0;

                                final lines =
                                    priceLinesBySaleBuyer[saleBuyerId] ?? [];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Card(
                                    margin: EdgeInsets.zero,
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${index + 1}. $buyerName',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          const SizedBox(height: 10),

                                          if (lines.isEmpty)
                                            Text(
                                              'No price lines found.',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                              ),
                                            )
                                          else
                                            ...lines.map((line) {
                                              final kilo =
                                                  (line['bundle_count'] as num?)
                                                      ?.toInt() ??
                                                  0;
                                              final price =
                                                  double.tryParse(
                                                    line['price_per_bundle']
                                                            ?.toString() ??
                                                        '0',
                                                  ) ??
                                                  0;
                                              final lineTotal =
                                                  double.tryParse(
                                                    line['line_total']
                                                            ?.toString() ??
                                                        '0',
                                                  ) ??
                                                  (kilo * price);

                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 3,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '$kilo × ${price.toStringAsFixed(2)} Birr',
                                                      ),
                                                    ),
                                                    Text(
                                                      _formatAmount(lineTotal),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),

                                          const Divider(height: 20),

                                          _DetailRow(
                                            label: 'Buyer Total',
                                            value: _formatAmount(buyerTotal),
                                            bold: true,
                                          ),

                                          _DetailRow(
                                            label: 'Paid',
                                            value: _formatAmount(paid),
                                          ),

                                          _DetailRow(
                                            label: 'Unpaid',
                                            value: _formatAmount(unpaid),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),

                            const Divider(height: 28),

                            // ==================================================
                            // SALE TOTALS
                            // ==================================================
                            const Text(
                              'Sale Totals',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            _DetailRow(
                              label: 'Total Sales',
                              value: _formatAmount(totalSales),
                              bold: true,
                            ),

                            _DetailRow(
                              label: 'Commission',
                              value: _formatAmount(commission),
                            ),

                            _DetailRow(
                              label: 'Advance Loan',
                              value: _formatAmount(advanceLoan),
                            ),

                            _DetailRow(
                              label: 'Farmer Amount',
                              value: _formatAmount(farmerAmount),
                              bold: true,
                            ),

                            const SizedBox(height: 16),

                            // ==================================================
                            // EDIT SALE BUTTON
                            // ==================================================
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text(
                                  'Edit Sale',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () async {
                                  // 1. Close the sale details sheet
                                  Navigator.of(context).pop();

                                  // 2. Open the EditSaleScreen
                                  final edited = await Navigator.of(context)
                                      .push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EditSaleScreen(saleId: saleId),
                                        ),
                                      );

                                  // 3. If edited successfully, refresh transactions list
                                  if (edited == true && mounted) {
                                    _loadTransactions();
                                  }
                                },
                              ),
                            ),

                            const SizedBox(height: 10),

                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Close'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load complete sale details: $e')),
      );
    }
  }

  // ============================================================
  // FARMER WITHDRAWAL DETAILS
  // ============================================================

  Future<void> _showWithdrawalDetails(Map<String, dynamic> transaction) async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Farmer Withdrawal',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                _DetailRow(
                  label: 'Farmer',
                  value:
                      transaction['farmer_name']?.toString() ??
                      'Unknown Farmer',
                  bold: true,
                ),

                _DetailRow(
                  label: 'Date',
                  value: transaction['date']?.toString() ?? '-',
                ),

                _DetailRow(
                  label: 'Amount',
                  value: _formatAmount(transaction['amount']),
                  bold: true,
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BUYER PAYMENT DETAILS
  // ============================================================

  Future<void> _showBuyerPaymentDetails(
    Map<String, dynamic> transaction,
  ) async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buyer Debt Payment',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                _DetailRow(
                  label: 'Buyer',
                  value:
                      transaction['buyer_name']?.toString() ?? 'Unknown Buyer',
                  bold: true,
                ),

                _DetailRow(
                  label: 'Date',
                  value: transaction['date']?.toString() ?? '-',
                ),

                _DetailRow(
                  label: 'Amount Paid',
                  value: _formatAmount(transaction['amount']),
                  bold: true,
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BUYER DEBT ADJUSTMENT DETAILS
  // ============================================================

  Future<void> _showBuyerAdjustmentDetails(
    Map<String, dynamic> transaction,
  ) async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buyer Debt Adjustment',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                _DetailRow(
                  label: 'Buyer',
                  value:
                      transaction['buyer_name']?.toString() ?? 'Unknown Buyer',
                  bold: true,
                ),

                _DetailRow(
                  label: 'Old Debt',
                  value: _formatAmount(transaction['old_balance']),
                ),

                _DetailRow(
                  label: 'New Debt',
                  value: _formatAmount(transaction['new_balance']),
                  bold: true,
                ),

                const Divider(height: 24),

                _DetailRow(
                  label: 'Reason',
                  value: transaction['reason']?.toString() ?? '-',
                ),

                _DetailRow(
                  label: 'Date',
                  value: transaction['date']?.toString() ?? '-',
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // FARMER BALANCE ADJUSTMENT DETAILS
  // ============================================================

  Future<void> _showFarmerAdjustmentDetails(
    Map<String, dynamic> transaction,
  ) async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Farmer Balance Adjustment',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                _DetailRow(
                  label: 'Farmer',
                  value:
                      transaction['farmer_name']?.toString() ??
                      'Unknown Farmer',
                  bold: true,
                ),

                _DetailRow(
                  label: 'Old Balance',
                  value: _formatAmount(transaction['old_balance']),
                ),

                _DetailRow(
                  label: 'New Balance',
                  value: _formatAmount(transaction['new_balance']),
                  bold: true,
                ),

                const Divider(height: 24),

                _DetailRow(
                  label: 'Reason',
                  value: transaction['reason']?.toString() ?? '-',
                ),

                _DetailRow(
                  label: 'Date',
                  value: transaction['date']?.toString() ?? '-',
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // OPEN TRANSACTION
  // ============================================================

  void _openTransaction(Map<String, dynamic> transaction) {
    final type = transaction['type']?.toString() ?? '';

    switch (type) {
      case 'Sale':
        _showSaleDetails(transaction);
        break;

      case 'Farmer Withdrawal':
        _showWithdrawalDetails(transaction);
        break;

      case 'Buyer Payment':
        _showBuyerPaymentDetails(transaction);
        break;

      case 'Debt Adjustment':
        _showBuyerAdjustmentDetails(transaction);
        break;

      case 'Farmer Balance Adjustment':
        _showFarmerAdjustmentDetails(transaction);
        break;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final transactions = _filteredTransactions;

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),

      body: Column(
        children: [
          const SizedBox(height: 12),

          // ========================================================
          // SEARCH
          // ========================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ========================================================
          // FILTERS
          // ========================================================
          SizedBox(
            height: 45,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _selectedFilter == 'All',
                  onSelected: () {
                    setState(() {
                      _selectedFilter = 'All';
                    });
                  },
                ),

                _FilterChip(
                  label: 'Sale',
                  selected: _selectedFilter == 'Sale',
                  onSelected: () {
                    setState(() {
                      _selectedFilter = 'Sale';
                    });
                  },
                ),

                _FilterChip(
                  label: 'Farmer Withdrawal',
                  selected: _selectedFilter == 'Farmer Withdrawal',
                  onSelected: () {
                    setState(() {
                      _selectedFilter = 'Farmer Withdrawal';
                    });
                  },
                ),

                _FilterChip(
                  label: 'Buyer Payment',
                  selected: _selectedFilter == 'Buyer Payment',
                  onSelected: () {
                    setState(() {
                      _selectedFilter = 'Buyer Payment';
                    });
                  },
                ),

                _FilterChip(
                  label: 'Debt Adjustment',
                  selected: _selectedFilter == 'Debt Adjustment',
                  onSelected: () {
                    setState(() {
                      _selectedFilter = 'Debt Adjustment';
                    });
                  },
                ),

                _FilterChip(
                  label: 'Farmer Balance Adjustment',
                  selected: _selectedFilter == 'Farmer Balance Adjustment',
                  onSelected: () {
                    setState(() {
                      _selectedFilter = 'Farmer Balance Adjustment';
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ========================================================
          // TRANSACTION LIST
          // ========================================================
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactions.isEmpty
                ? RefreshIndicator(
                    onRefresh: _loadTransactions,
                    child: ListView(
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('No transactions found.')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTransactions,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];

                        final type =
                            transaction['type']?.toString() ?? 'Transaction';

                        final amount = transaction['amount'];

                        final farmerName = transaction['farmer_name']
                            ?.toString();

                        final sellerName = transaction['seller_name']
                            ?.toString();

                        final buyerName = transaction['buyer_name']?.toString();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            onTap: () {
                              _openTransaction(transaction);
                            },

                            leading: CircleAvatar(
                              child: Icon(_transactionIcon(type)),
                            ),

                            title: Text(
                              type,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ==================================================
                                // SALE
                                // ==================================================
                                if (type == 'Sale') ...[
                                  if (farmerName != null)
                                    Text('Farmer: $farmerName'),

                                  if (sellerName != null)
                                    Text('Seller: $sellerName'),

                                  Text(transaction['code']?.toString() ?? ''),

                                  Text(
                                    transaction['details']?.toString() ?? '',
                                  ),

                                  Text(transaction['date']?.toString() ?? ''),
                                ]
                                // ==================================================
                                // FARMER WITHDRAWAL
                                // ==================================================
                                else if (type == 'Farmer Withdrawal') ...[
                                  if (farmerName != null)
                                    Text('Farmer: $farmerName'),

                                  Text(
                                    transaction['details']?.toString() ?? '',
                                  ),

                                  Text(transaction['date']?.toString() ?? ''),
                                ]
                                // ==================================================
                                // BUYER PAYMENT
                                // ==================================================
                                else if (type == 'Buyer Payment') ...[
                                  if (buyerName != null)
                                    Text('Buyer: $buyerName'),

                                  Text(
                                    transaction['details']?.toString() ?? '',
                                  ),

                                  Text(transaction['date']?.toString() ?? ''),
                                ]
                                // ==================================================
                                // DEBT ADJUSTMENT
                                // ==================================================
                                else if (type == 'Debt Adjustment') ...[
                                  if (buyerName != null)
                                    Text('Buyer: $buyerName'),

                                  Text(
                                    transaction['details']?.toString() ?? '',
                                  ),

                                  Text(transaction['date']?.toString() ?? ''),
                                ]
                                // ==================================================
                                // FARMER BALANCE ADJUSTMENT
                                // ==================================================
                                else if (type ==
                                    'Farmer Balance Adjustment') ...[
                                  if (farmerName != null)
                                    Text('Farmer: $farmerName'),

                                  Text(
                                    transaction['details']?.toString() ?? '',
                                  ),

                                  Text(transaction['date']?.toString() ?? ''),
                                ]
                                // ==================================================
                                // FALLBACK
                                // ==================================================
                                else ...[
                                  Text(transaction['code']?.toString() ?? ''),

                                  Text(
                                    transaction['details']?.toString() ?? '',
                                  ),

                                  Text(transaction['date']?.toString() ?? ''),
                                ],
                              ],
                            ),

                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatAmount(amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// DETAIL ROW
// ==================================================================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),

          const SizedBox(width: 20),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// FILTER CHIP
// ==================================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          onSelected();
        },
      ),
    );
  }
}
