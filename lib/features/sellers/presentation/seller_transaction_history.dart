import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerTransactionHistory extends StatefulWidget {
  final dynamic sellerId;
  final int refreshTrigger;

  const SellerTransactionHistory({
    super.key,
    required this.sellerId,
    this.refreshTrigger = 0,
  });

  @override
  State<SellerTransactionHistory> createState() =>
      _SellerTransactionHistoryState();
}

class _SellerTransactionHistoryState extends State<SellerTransactionHistory> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;

  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _adjustments = [];

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
  void didUpdateWidget(covariant SellerTransactionHistory oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshTrigger != widget.refreshTrigger ||
        oldWidget.sellerId.toString() != widget.sellerId.toString()) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final sellerId = widget.sellerId;

      // --------------------------------------------------------------
      // SALES: only sales where this seller sold to Magala.
      // --------------------------------------------------------------
      final salesData = await _supabase
          .from('sales')
          .select('''
            id,
            transaction_code,
            sale_date,
            total_bundles,
            seller_id,
            farmer_id,
            farmers(full_name)
          ''')
          .eq('seller_id', sellerId)
          .order('sale_date', ascending: false);

      final salesRows = List<Map<String, dynamic>>.from(salesData);
      final saleIds = salesRows
          .map((sale) => sale['id'])
          .where((id) => id != null)
          .toList();

      final Map<String, Map<String, dynamic>> saleById = {
        for (final sale in salesRows)
          if (sale['id'] != null) sale['id'].toString(): sale,
      };

      final saleBuyers = <Map<String, dynamic>>[];

      if (saleIds.isNotEmpty) {
        final magalaBuyersData = await _supabase
            .from('buyers')
            .select('id')
            .eq('is_magala', true);

        final magalaBuyerIds = List<Map<String, dynamic>>.from(
          magalaBuyersData,
        )
            .map((buyer) => buyer['id'])
            .where((id) => id != null)
            .toList();

        if (magalaBuyerIds.isNotEmpty) {
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
              .inFilter('sale_id', saleIds)
              .inFilter('buyer_id', magalaBuyerIds)
              .order('created_at', ascending: false);

          saleBuyers.addAll(
            List<Map<String, dynamic>>.from(saleBuyersData),
          );
        }
      }

      final saleBuyerIds = saleBuyers
          .map((row) => row['id'])
          .where((id) => id != null)
          .toList();

      final Map<String, List<Map<String, dynamic>>> priceLinesBySaleBuyer =
          {};

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

        for (final line in List<Map<String, dynamic>>.from(priceLinesData)) {
          final saleBuyerId = line['sale_buyer_id']?.toString();
          if (saleBuyerId == null) continue;

          priceLinesBySaleBuyer.putIfAbsent(saleBuyerId, () => []);
          priceLinesBySaleBuyer[saleBuyerId]!.add(
            Map<String, dynamic>.from(line),
          );
        }
      }

      final sales = <Map<String, dynamic>>[];

      for (final saleBuyer in saleBuyers) {
        final saleId = saleBuyer['sale_id']?.toString();
        final saleBuyerId = saleBuyer['id']?.toString();

        if (saleId == null || saleBuyerId == null) continue;

        final sale = saleById[saleId];
        if (sale == null) continue;

        final sellerSale = Map<String, dynamic>.from(sale);
        sellerSale['sale_buyer_id'] = saleBuyerId;
        sellerSale['total_amount'] = saleBuyer['total_amount'];
        sellerSale['paid_amount'] = saleBuyer['paid_amount'];
        sellerSale['unpaid_amount'] = saleBuyer['unpaid_amount'];
        sellerSale['price_lines'] = priceLinesBySaleBuyer[saleBuyerId] ?? [];

        int kilo = 0;
        final rawLines = sellerSale['price_lines'];
        if (rawLines is List) {
          for (final line in rawLines) {
            if (line is Map) {
              kilo += (line['bundle_count'] as num?)?.toInt() ?? 0;
            }
          }
        }

        sellerSale['seller_kilo'] = kilo;
        sales.add(sellerSale);
      }

      // --------------------------------------------------------------
      // DEBT PAYMENTS
      // --------------------------------------------------------------
      final paymentsData = await _supabase
          .from('seller_debt_payments')
          .select('''
            id,
            seller_id,
            amount,
            payment_date,
            remaining_debt,
            recorded_by
          ''')
          .eq('seller_id', sellerId)
          .order('payment_date', ascending: false);

      final payments = List<Map<String, dynamic>>.from(paymentsData);

      // --------------------------------------------------------------
      // DEBT ADJUSTMENTS
      // --------------------------------------------------------------
      final adjustmentsData = await _supabase
          .from('seller_debt_adjustments')
          .select('''
            id,
            seller_id,
            old_balance,
            new_balance,
            reason,
            adjusted_by,
            created_at
          ''')
          .eq('seller_id', sellerId)
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
          content: Text('Could not load seller transaction history: $e'),
        ),
      );
    }
  }

  String _normalizeDate(String value) => value.trim().replaceAll('/', '-');

  bool _matchesDateSearch(String? dateValue) {
    if (_dateSearch.isEmpty) return true;
    if (dateValue == null || dateValue.isEmpty) return false;

    final search = _normalizeDate(_dateSearch);
    final date = dateValue.length >= 10 ? dateValue.substring(0, 10) : dateValue;

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(search)) {
      return date == search;
    }

    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(search)) {
      return date.startsWith(search);
    }

    if (RegExp(r'^\d{4}$').hasMatch(search)) {
      return date.startsWith(search);
    }

    return date.contains(search);
  }

  List<Map<String, dynamic>> get _filteredSales =>
      _sales.where((sale) => _matchesDateSearch(sale['sale_date']?.toString())).toList();

  List<Map<String, dynamic>> get _filteredPayments => _payments
      .where((payment) => _matchesDateSearch(payment['payment_date']?.toString()))
      .toList();

  List<Map<String, dynamic>> get _filteredAdjustments => _adjustments
      .where((adjustment) => _matchesDateSearch(adjustment['created_at']?.toString()))
      .toList();

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
            child: Icon(Icons.scale_outlined, size: 20, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$kilo × ${price.toStringAsFixed(2)} = ${lineTotal.toStringAsFixed(2)} Birr',
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
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, double amount, {Color? color, bool emphasized = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: emphasized ? FontWeight.bold : FontWeight.w500),
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

  Widget _emptyHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No transaction history',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 5),
            Text(
              'Magala sales, debt payments and debt adjustments will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noSearchResults(String type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.search_off_outlined, size: 46, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              'No $type found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
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

  Widget _saleCard(Map<String, dynamic> sale) {
    final farmerData = sale['farmers'];
    final farmerName = farmerData is Map
        ? farmerData['full_name']?.toString() ?? 'Unknown farmer'
        : 'Unknown farmer';

    final date = sale['sale_date']?.toString() ?? 'Unknown date';
    final code = sale['transaction_code']?.toString() ?? 'No code';
    final kilo = (sale['seller_kilo'] as num?)?.toInt() ?? 0;
    final totalAmount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
    final paidAmount = (sale['paid_amount'] as num?)?.toDouble() ?? 0;
    final unpaidAmount = (sale['unpaid_amount'] as num?)?.toDouble() ?? 0;

    final rawPriceLines = sale['price_lines'];
    final priceLines = <Map<String, dynamic>>[];
    if (rawPriceLines is List) {
      for (final line in rawPriceLines) {
        if (line is Map) priceLines.add(Map<String, dynamic>.from(line));
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.point_of_sale_outlined, color: Colors.green.shade700),
        ),
        title: const Text('Magala Sale', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$date • $code'),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        children: [
          const Divider(),
          _infoRow('Date', date, Icons.calendar_today_outlined),
          _infoRow('Transaction Code', code, Icons.tag_outlined),
          _infoRow('Farmer', farmerName, Icons.person_outline),
          _infoRow('Kilo Sold to Magala', '$kilo', Icons.inventory_2_outlined),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.price_change_outlined, size: 20, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Kilo & Price',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
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
              child: Text(
                'No price line information',
                style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w500),
              ),
            )
          else
            ...priceLines.map(_buildPriceLine),
          const SizedBox(height: 10),
          _moneyRow('Total Sale Amount', totalAmount, emphasized: true),
          const Divider(height: 22),
          _moneyRow('Magala Paid', paidAmount, color: Colors.green.shade700),
          _moneyRow(
            'Magala Unpaid',
            unpaidAmount,
            color: unpaidAmount > 0 ? Colors.red.shade700 : Colors.green.shade700,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${paidAmount.toStringAsFixed(2)} Birr paid by Magala was added to this seller\'s debt.',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        title: const Text('Debt Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(date),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        children: [
          const Divider(),
          _infoRow('Payment Date', date, Icons.calendar_today_outlined),
          _moneyRow('Amount Paid', amount, color: Colors.green.shade700, emphasized: true),
          _moneyRow(
            'Remaining Debt',
            remainingDebt,
            color: remainingDebt > 0 ? Colors.orange.shade700 : Colors.green.shade700,
            emphasized: true,
          ),
          const SizedBox(height: 4),
          Text(
            'This payment was recorded as a separate debt transaction and does not modify the original sale record.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

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
        title: const Text('Debt Adjustment', style: TextStyle(fontWeight: FontWeight.bold)),
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
          _moneyRow('New Debt', newBalance, emphasized: true, color: Colors.purple.shade700),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Reason', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(reason, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    final sales = _filteredSales;
    if (sales.isEmpty) {
      return _dateSearch.isNotEmpty ? _noSearchResults('sales') : _emptyHistory();
    }
    return Column(children: [...sales.map(_saleCard)]);
  }

  Widget _buildPaymentsTab() {
    final payments = _filteredPayments;
    if (payments.isEmpty) {
      return _dateSearch.isNotEmpty ? _noSearchResults('debt payments') : _emptyHistory();
    }
    return Column(children: [...payments.map(_paymentCard)]);
  }

  Widget _buildAdjustmentsTab() {
    final adjustments = _filteredAdjustments;
    if (adjustments.isEmpty) {
      return _dateSearch.isNotEmpty ? _noSearchResults('debt adjustments') : _emptyHistory();
    }
    return Column(children: [...adjustments.map(_adjustmentCard)]);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      );
    }

    final hasHistory = _sales.isNotEmpty || _payments.isNotEmpty || _adjustments.isNotEmpty;
    if (!hasHistory) return _emptyHistory();

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transaction History', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
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
                Tab(icon: Icon(Icons.edit_note_outlined), text: 'Debt Adjustments'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 650,
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
