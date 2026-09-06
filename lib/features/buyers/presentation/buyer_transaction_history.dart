import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BuyerTransactionHistory extends StatefulWidget {
  final dynamic buyerId;
  final int refreshTrigger;

  const BuyerTransactionHistory({
    super.key,
    required this.buyerId,
    this.refreshTrigger = 0,
  });

  @override
  State<BuyerTransactionHistory> createState() =>
      _BuyerTransactionHistoryState();
}

class _BuyerTransactionHistoryState extends State<BuyerTransactionHistory> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;

  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _adjustments = [];

  // ================================================================
  // DATE SEARCH
  // ================================================================

  final TextEditingController _dateSearchController = TextEditingController();

  String _dateSearch = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _dateSearchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BuyerTransactionHistory oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshTrigger != widget.refreshTrigger ||
        oldWidget.buyerId.toString() != widget.buyerId.toString()) {
      _loadHistory();
    }
  }

  // ================================================================
  // LOAD EVERYTHING
  // ================================================================

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final buyerId = widget.buyerId;

      // ============================================================
      // SALES FOR THIS BUYER
      // ============================================================

      final saleBuyersData = await _supabase
          .from('sale_buyers')
          .select('''
            id,
            sale_id,
            buyer_id,
            total_amount,
            paid_amount,
            unpaid_amount,
            created_at
          ''')
          .eq('buyer_id', buyerId)
          .order('created_at', ascending: false);

      final saleBuyers = List<Map<String, dynamic>>.from(saleBuyersData);

      final saleIds = saleBuyers
          .map((saleBuyer) => saleBuyer['sale_id'])
          .where((id) => id != null)
          .toList();

      final Map<String, Map<String, dynamic>> salesById = {};

      if (saleIds.isNotEmpty) {
        final salesData = await _supabase
            .from('sales')
            .select('''
              id,
              transaction_code,
              sale_date,
              total_bundles,
              seller_id,
              sellers(full_name)
            ''')
            .inFilter('id', saleIds);

        final sales = List<Map<String, dynamic>>.from(salesData);

        for (final sale in sales) {
          final saleId = sale['id']?.toString();

          if (saleId != null) {
            salesById[saleId] = sale;
          }
        }
      }

      // ============================================================
      // PRICE LINES
      // ============================================================

      final saleBuyerIds = saleBuyers
          .map((saleBuyer) => saleBuyer['id'])
          .where((id) => id != null)
          .toList();

      final Map<String, List<Map<String, dynamic>>> priceLinesBySaleBuyer = {};

      if (saleBuyerIds.isNotEmpty) {
        final priceLinesData = await _supabase
            .from('sale_price_lines')
            .select('''
              id,
              sale_buyer_id,
              bundle_count,
              price_per_bundle,
              line_total
            ''')
            .inFilter('sale_buyer_id', saleBuyerIds);

        final priceLines = List<Map<String, dynamic>>.from(priceLinesData);

        for (final line in priceLines) {
          final saleBuyerId = line['sale_buyer_id']?.toString();

          if (saleBuyerId == null) continue;

          priceLinesBySaleBuyer.putIfAbsent(saleBuyerId, () => []);

          priceLinesBySaleBuyer[saleBuyerId]!.add(
            Map<String, dynamic>.from(line),
          );
        }
      }

      // ============================================================
      // BUILD BUYER SALES
      // ============================================================

      final sales = <Map<String, dynamic>>[];

      for (final saleBuyer in saleBuyers) {
        final saleId = saleBuyer['sale_id']?.toString();
        final saleBuyerId = saleBuyer['id']?.toString();

        if (saleId == null || saleBuyerId == null) {
          continue;
        }

        final sale = salesById[saleId];

        if (sale == null) {
          continue;
        }

        final buyerSale = Map<String, dynamic>.from(sale);

        buyerSale['sale_buyer_id'] = saleBuyerId;
        buyerSale['total_amount'] = saleBuyer['total_amount'];
        buyerSale['paid_amount'] = saleBuyer['paid_amount'];
        buyerSale['unpaid_amount'] = saleBuyer['unpaid_amount'];

        buyerSale['price_lines'] = priceLinesBySaleBuyer[saleBuyerId] ?? [];

        // Calculate kilo bought by this buyer from its price lines.
        final priceLines = buyerSale['price_lines'];

        int buyerKilo = 0;

        if (priceLines is List) {
          for (final line in priceLines) {
            if (line is Map) {
              buyerKilo += (line['bundle_count'] as num?)?.toInt() ?? 0;
            }
          }
        }

        buyerSale['buyer_kilo'] = buyerKilo;

        sales.add(buyerSale);
      }

      // ============================================================
      // DEBT PAYMENTS
      // ============================================================

      final paymentsData = await _supabase
          .from('buyer_debt_payments')
          .select('''
            id,
            buyer_id,
            amount,
            remaining_debt,
            payment_date,
            recorded_by
          ''')
          .eq('buyer_id', buyerId)
          .order('payment_date', ascending: false);

      final payments = List<Map<String, dynamic>>.from(paymentsData);

      // ============================================================
      // DEBT ADJUSTMENTS
      // ============================================================

      final adjustmentsData = await _supabase
          .from('buyer_debt_adjustments')
          .select('''
            id,
            buyer_id,
            old_balance,
            new_balance,
            reason,
            adjusted_by,
            created_at
          ''')
          .eq('buyer_id', buyerId)
          .order('created_at', ascending: false);

      final adjustments = List<Map<String, dynamic>>.from(adjustmentsData);

      if (!mounted) return;

      setState(() {
        _sales = sales;
        _payments = payments;
        _adjustments = adjustments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Could not load buyer transaction history: $e'),
        ),
      );
    }
  }

  // ================================================================
  // DATE SEARCH HELPERS
  // ================================================================

  String _normalizeDate(String value) {
    return value.trim().replaceAll('/', '-');
  }

  bool _matchesDateSearch(String? dateValue) {
    if (_dateSearch.isEmpty) {
      return true;
    }

    if (dateValue == null || dateValue.isEmpty) {
      return false;
    }

    final search = _normalizeDate(_dateSearch);

    final date = dateValue.length >= 10
        ? dateValue.substring(0, 10)
        : dateValue;

    // Full date: 2026-08-30
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(search)) {
      return date == search;
    }

    // Month: 2026-08
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(search)) {
      return date.startsWith(search);
    }

    // Year: 2026
    if (RegExp(r'^\d{4}$').hasMatch(search)) {
      return date.startsWith(search);
    }

    return date.contains(search);
  }

  List<Map<String, dynamic>> get _filteredSales {
    return _sales.where((sale) {
      return _matchesDateSearch(sale['sale_date']?.toString());
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredPayments {
    return _payments.where((payment) {
      return _matchesDateSearch(payment['payment_date']?.toString());
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredAdjustments {
    return _adjustments.where((adjustment) {
      return _matchesDateSearch(adjustment['created_at']?.toString());
    }).toList();
  }

  // ================================================================
  // DATE SEARCH UI
  // ================================================================

  Future<void> _pickDate() async {
    final now = DateTime.now();

    DateTime initialDate = now;

    final currentSearch = _normalizeDate(_dateSearch);

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(currentSearch)) {
      try {
        initialDate = DateTime.parse(currentSearch);
      } catch (_) {
        initialDate = now;
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
    );

    if (picked == null || !mounted) return;

    final formatted =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';

    setState(() {
      _dateSearch = formatted;
      _dateSearchController.text = formatted;
    });
  }

  void _clearDateSearch() {
    setState(() {
      _dateSearch = '';
      _dateSearchController.clear();
    });
  }

  Widget _buildDateSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _dateSearchController,
          keyboardType: TextInputType.datetime,
          onChanged: (value) {
            setState(() {
              _dateSearch = value.trim();
            });
          },
          decoration: InputDecoration(
            labelText: 'Search by date',
            hintText: 'YYYY, YYYY-MM or YYYY-MM-DD',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_dateSearch.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear date search',
                    icon: const Icon(Icons.clear),
                    onPressed: _clearDateSearch,
                  ),
                IconButton(
                  tooltip: 'Choose date',
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: _pickDate,
                ),
              ],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Examples: 2026 • 2026-08 • 2026-08-30',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ================================================================
  // PRICE LINE
  // ================================================================

  Widget _buildPriceLine(Map<String, dynamic> line) {
    final kilo = (line['bundle_count'] as num?)?.toInt() ?? 0;

    final price = (line['price_per_bundle'] as num?)?.toDouble() ?? 0;

    final lineTotal = (line['line_total'] as num?)?.toDouble() ?? 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.indigo.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.scale_outlined,
              size: 20,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$kilo × ${price.toStringAsFixed(2)} = '
              '${lineTotal.toStringAsFixed(2)} Birr',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // INFO ROW
  // ================================================================

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // MONEY ROW
  // ================================================================

  Widget _moneyRow(
    String label,
    double amount, {
    Color? color,
    bool emphasized = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} Birr',
            style: TextStyle(
              color: color,
              fontWeight: emphasized ? FontWeight.bold : FontWeight.w600,
              fontSize: emphasized ? 15 : 14,
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // EMPTY STATE
  // ================================================================

  Widget _emptyHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 52,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No transaction history',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Sales, debt payments and debt '
              'adjustments will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // NO SEARCH RESULTS
  // ================================================================

  Widget _noSearchResults(String type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 46,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            Text(
              'No $type found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'No transaction matches "$_dateSearch".',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // SALE CARD
  // ================================================================

  Widget _saleCard(Map<String, dynamic> sale) {
    final sellerData = sale['sellers'];

    final sellerName = sellerData is Map
        ? sellerData['full_name']?.toString() ?? 'Unknown seller'
        : 'Unknown seller';

    final date = sale['sale_date']?.toString() ?? 'Unknown date';

    final code = sale['transaction_code']?.toString() ?? 'No code';

    final kilo = (sale['buyer_kilo'] as num?)?.toInt() ?? 0;

    final totalAmount = (sale['total_amount'] as num?)?.toDouble() ?? 0;

    final paidAmount = (sale['paid_amount'] as num?)?.toDouble() ?? 0;

    final unpaidAmount = (sale['unpaid_amount'] as num?)?.toDouble() ?? 0;

    final rawPriceLines = sale['price_lines'];

    final List<Map<String, dynamic>> priceLines = [];

    if (rawPriceLines is List) {
      for (final line in rawPriceLines) {
        if (line is Map) {
          priceLines.add(Map<String, dynamic>.from(line));
        }
      }
    }

    String paymentStatus;

    if (unpaidAmount <= 0) {
      paymentStatus = 'Paid';
    } else if (paidAmount > 0) {
      paymentStatus = 'Partially Paid';
    } else {
      paymentStatus = 'Unpaid';
    }

    Color paymentColor;

    if (unpaidAmount <= 0) {
      paymentColor = Colors.green.shade700;
    } else if (paidAmount > 0) {
      paymentColor = Colors.orange.shade700;
    } else {
      paymentColor = Colors.red.shade700;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(
            Icons.point_of_sale_outlined,
            color: Colors.green.shade700,
          ),
        ),
        title: const Text(
          'Sale',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$date • $code'),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        children: [
          const Divider(),
          _infoRow('Date', date, Icons.calendar_today_outlined),
          _infoRow('Transaction Code', code, Icons.tag_outlined),
          _infoRow('Seller', sellerName, Icons.person_outline),
          _infoRow('Kilo Bought', '$kilo', Icons.inventory_2_outlined),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.price_change_outlined,
                size: 20,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'Kilo & Price',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (priceLines.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 19,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No price line information',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...priceLines.map(_buildPriceLine),
          const SizedBox(height: 10),
          _moneyRow('Total Sale Amount', totalAmount, emphasized: true),
          const Divider(height: 22),
          _moneyRow('Paid', paidAmount, color: Colors.green.shade700),
          _moneyRow(
            'Unpaid',
            unpaidAmount,
            color: unpaidAmount > 0
                ? Colors.red.shade700
                : Colors.green.shade700,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: paymentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  unpaidAmount <= 0
                      ? Icons.check_circle_outline
                      : Icons.pending_outlined,
                  size: 20,
                  color: paymentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Payment Status: $paymentStatus',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: paymentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // DEBT PAYMENT CARD
  // ================================================================

  Widget _paymentCard(Map<String, dynamic> payment) {
    final date = payment['payment_date']?.toString() ?? 'Unknown date';

    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;

    final remainingDebt = (payment['remaining_debt'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.payments_outlined, color: Colors.green.shade700),
        ),
        title: const Text(
          'Debt Payment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(date),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        children: [
          const Divider(),
          _infoRow('Payment Date', date, Icons.calendar_today_outlined),
          _moneyRow(
            'Amount Paid',
            amount,
            color: Colors.green.shade700,
            emphasized: true,
          ),
          _moneyRow(
            'Remaining Debt',
            remainingDebt,
            color: remainingDebt > 0
                ? Colors.orange.shade700
                : Colors.green.shade700,
            emphasized: true,
          ),
          const SizedBox(height: 4),
          Text(
            'This payment was recorded as a separate '
            'debt transaction and does not modify the '
            'original sale record.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // DEBT ADJUSTMENT CARD
  // ================================================================

  Widget _adjustmentCard(Map<String, dynamic> adjustment) {
    final date = adjustment['created_at']?.toString() ?? 'Unknown date';

    final oldBalance = (adjustment['old_balance'] as num?)?.toDouble() ?? 0;

    final newBalance = (adjustment['new_balance'] as num?)?.toDouble() ?? 0;

    final changed = newBalance - oldBalance;

    final reason = adjustment['reason']?.toString() ?? 'No reason provided';

    final increase = changed >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade100,
          child: Icon(Icons.edit_note_outlined, color: Colors.purple.shade700),
        ),
        title: const Text(
          'Debt Adjustment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(date),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        children: [
          const Divider(),
          _infoRow('Date', date, Icons.calendar_today_outlined),
          _moneyRow('Old Debt', oldBalance),
          _moneyRow(
            'Amount Changed',
            changed,
            color: increase ? Colors.green.shade700 : Colors.red.shade700,
          ),
          _moneyRow(
            'New Debt',
            newBalance,
            emphasized: true,
            color: Colors.purple.shade700,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Reason',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              reason,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // BUILD TAB CONTENT
  // ================================================================

  Widget _buildSalesTab() {
    final sales = _filteredSales;

    if (sales.isEmpty) {
      if (_dateSearch.isNotEmpty) {
        return _noSearchResults('sales');
      }

      return _emptyHistory();
    }

    return Column(children: [...sales.map(_saleCard)]);
  }

  Widget _buildPaymentsTab() {
    final payments = _filteredPayments;

    if (payments.isEmpty) {
      if (_dateSearch.isNotEmpty) {
        return _noSearchResults('debt payments');
      }

      return _emptyHistory();
    }

    return Column(children: [...payments.map(_paymentCard)]);
  }

  Widget _buildAdjustmentsTab() {
    final adjustments = _filteredAdjustments;

    if (adjustments.isEmpty) {
      if (_dateSearch.isNotEmpty) {
        return _noSearchResults('debt adjustments');
      }

      return _emptyHistory();
    }

    return Column(children: [...adjustments.map(_adjustmentCard)]);
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    final hasHistory =
        _sales.isNotEmpty || _payments.isNotEmpty || _adjustments.isNotEmpty;

    if (!hasHistory) {
      return _emptyHistory();
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transaction History',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          _buildDateSearch(),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(icon: Icon(Icons.point_of_sale_outlined), text: 'Sales'),
                Tab(icon: Icon(Icons.payments_outlined), text: 'Debt Payments'),
                Tab(
                  icon: Icon(Icons.edit_note_outlined),
                  text: 'Debt Adjustments',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 600,
            child: TabBarView(
              children: [
                SingleChildScrollView(child: _buildSalesTab()),
                SingleChildScrollView(child: _buildPaymentsTab()),
                SingleChildScrollView(child: _buildAdjustmentsTab()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
