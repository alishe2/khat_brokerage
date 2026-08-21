import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final sales = await _supabase
          .from('sales')
          .select(
            'id, transaction_code, sale_date, total_bundles, '
            'total_sales, commission_amount, farmer_amount, created_at',
          )
          .order('created_at', ascending: false);

      final withdrawals = await _supabase
          .from('farmer_withdrawals')
          .select(
            'id, farmer_id, amount, withdrawal_date, created_at',
          )
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> combined = [];

      for (final sale in sales) {
        combined.add({
          'id': sale['id'],
          'type': 'Sale',
          'code': sale['transaction_code'],
          'date': sale['sale_date'],
          'amount': sale['total_sales'] ?? 0,
          'details':
              '${sale['total_bundles'] ?? 0} kilo',
          'created_at': sale['created_at'],
        });
      }

      for (final withdrawal in withdrawals) {
        combined.add({
          'id': withdrawal['id'],
          'type': 'Farmer Withdrawal',
          'code': 'Withdrawal',
          'date': withdrawal['withdrawal_date'],
          'amount': withdrawal['amount'] ?? 0,
          'details': 'Farmer withdrawal',
          'created_at': withdrawal['created_at'],
        });
      }

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
        SnackBar(
          content: Text(
            'Could not load transactions: $e',
          ),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_selectedFilter == 'All') {
      return _transactions;
    }

    return _transactions
        .where(
          (transaction) =>
              transaction['type'] == _selectedFilter,
        )
        .toList();
  }

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

      default:
        return Icons.swap_horiz_outlined;
    }
  }

  String _formatAmount(dynamic value) {
    final amount =
        double.tryParse(value.toString()) ?? 0;

    return '${amount.toStringAsFixed(2)} Birr';
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
      ),

      body: Column(
        children: [
          const SizedBox(height: 12),

          // Filters
          SizedBox(
            height: 45,
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12),
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
                  selected:
                      _selectedFilter ==
                          'Farmer Withdrawal',
                  onSelected: () {
                    setState(() {
                      _selectedFilter =
                          'Farmer Withdrawal';
                    });
                  },
                ),

                _FilterChip(
                  label: 'Buyer Payment',
                  selected:
                      _selectedFilter ==
                          'Buyer Payment',
                  onSelected: () {
                    setState(() {
                      _selectedFilter =
                          'Buyer Payment';
                    });
                  },
                ),

                _FilterChip(
                  label: 'Debt Adjustment',
                  selected:
                      _selectedFilter ==
                          'Debt Adjustment',
                  onSelected: () {
                    setState(() {
                      _selectedFilter =
                          'Debt Adjustment';
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : transactions.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadTransactions,
                        child: ListView(
                          children: const [
                            SizedBox(height: 180),
                            Center(
                              child: Text(
                                'No transactions found.',
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.all(12),
                          itemCount: transactions.length,
                          itemBuilder:
                              (context, index) {
                            final transaction =
                                transactions[index];

                            final type =
                                transaction['type']
                                    ?.toString() ??
                                'Transaction';

                            return Card(
                              margin:
                                  const EdgeInsets.only(
                                bottom: 10,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                    _transactionIcon(
                                      type,
                                    ),
                                  ),
                                ),

                                title: Text(
                                  type,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),

                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      transaction[
                                                  'code']
                                              ?.toString() ??
                                          '',
                                    ),
                                    Text(
                                      transaction[
                                                  'details']
                                              ?.toString() ??
                                          '',
                                    ),
                                    Text(
                                      transaction[
                                                  'date']
                                              ?.toString() ??
                                          '',
                                    ),
                                  ],
                                ),

                                trailing: Text(
                                  _formatAmount(
                                    transaction[
                                        'amount'],
                                  ),
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
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
      padding:
          const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}