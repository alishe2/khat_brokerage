import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditSaleScreen extends StatefulWidget {
  final String saleId;

  const EditSaleScreen({super.key, required this.saleId});

  @override
  State<EditSaleScreen> createState() => _EditSaleScreenState();
}

class _EditSaleScreenState extends State<EditSaleScreen> {
  final _supabase = Supabase.instance.client;

  final _totalBundlesController = TextEditingController();
  final _advanceLoanController = TextEditingController();
  final _reasonController = TextEditingController();

  List<Map<String, dynamic>> _farmers = [];
  List<Map<String, dynamic>> _sellers = [];
  List<Map<String, dynamic>> _buyers = [];

  String? _selectedFarmerId;
  String? _selectedSellerId;
  DateTime? _selectedDate;
  String _transactionCode = '';

  bool _isLoading = true;
  bool _isSaving = false;
  bool _showReasonError = false;

  final List<Map<String, dynamic>> _saleBuyers = [];

  @override
  void initState() {
    super.initState();
    _loadSale();
  }

  @override
  void dispose() {
    _disposeBuyerControllers();
    _totalBundlesController.dispose();
    _advanceLoanController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _disposeBuyerControllers() {
    for (final buyer in _saleBuyers) {
      final paid = buyer['paid_amount'];
      if (paid is TextEditingController) paid.dispose();

      final lines = buyer['lines'];
      if (lines is List) {
        for (final line in lines) {
          if (line is Map) {
            final bundles = line['bundle_count'];
            final price = line['price_per_bundle'];
            if (bundles is TextEditingController) bundles.dispose();
            if (price is TextEditingController) price.dispose();
          }
        }
      }
    }
  }

  Future<void> _loadSale() async {
    try {
      final results = await Future.wait([
        _supabase.from('farmers').select('id, farmer_code, full_name, phone').order('full_name'),
        _supabase.from('sellers').select('id, seller_code, full_name, phone').order('full_name'),
        _supabase.from('buyers').select('id, buyer_code, group_name, phone, is_magala, is_active').order('group_name'),
        _supabase.from('sales').select('id, transaction_code, farmer_id, seller_id, sale_date, total_bundles, advance_loan').eq('id', widget.saleId).maybeSingle(),
      ]);

      final sale = results[3] as Map<String, dynamic>?;
      if (sale == null) {
        throw Exception('Sale not found.');
      }

      final saleBuyersData = await _supabase
          .from('sale_buyers')
          .select('id, buyer_id, total_amount, paid_amount, unpaid_amount')
          .eq('sale_id', widget.saleId)
          .order('id');

      final saleBuyers = List<Map<String, dynamic>>.from(saleBuyersData);
      final saleBuyerIds = saleBuyers.map((e) => e['id']).where((e) => e != null).toList();

      List<Map<String, dynamic>> priceLines = [];
      if (saleBuyerIds.isNotEmpty) {
        final data = await _supabase
            .from('sale_price_lines')
            .select('id, sale_buyer_id, bundle_count, price_per_bundle, line_total')
            .inFilter('sale_buyer_id', saleBuyerIds)
            .order('id');
        priceLines = List<Map<String, dynamic>>.from(data);
      }

      final linesBySaleBuyer = <String, List<Map<String, dynamic>>>{};
      for (final line in priceLines) {
        final id = line['sale_buyer_id']?.toString();
        if (id == null) continue;
        linesBySaleBuyer.putIfAbsent(id, () => []).add(line);
      }

      for (final saleBuyer in saleBuyers) {
        final saleBuyerId = saleBuyer['id']?.toString();
        if (saleBuyerId == null) continue;

        final buyerEntry = <String, dynamic>{
          'buyer_id': saleBuyer['buyer_id']?.toString(),
          'paid_amount': TextEditingController(
            text: _numberText(saleBuyer['paid_amount']),
          ),
          'lines': <Map<String, dynamic>>[],
        };

        for (final line in linesBySaleBuyer[saleBuyerId] ?? []) {
          (buyerEntry['lines'] as List).add({
            'bundle_count': TextEditingController(
              text: (line['bundle_count'] ?? '').toString(),
            ),
            'price_per_bundle': TextEditingController(
              text: _numberText(line['price_per_bundle']),
            ),
          });
        }

        _saleBuyers.add(buyerEntry);
      }

      final saleDate = DateTime.tryParse(sale['sale_date']?.toString() ?? '');

      if (!mounted) return;

      setState(() {
        _farmers = List<Map<String, dynamic>>.from(results[0] as List);
        _sellers = List<Map<String, dynamic>>.from(results[1] as List);
        _buyers = List<Map<String, dynamic>>.from(results[2] as List);
        _selectedFarmerId = sale['farmer_id']?.toString();
        _selectedSellerId = sale['seller_id']?.toString();
        _selectedDate = saleDate;
        _transactionCode = sale['transaction_code']?.toString() ?? '';
        _totalBundlesController.text = (sale['total_bundles'] ?? '').toString();
        _advanceLoanController.text = _numberText(sale['advance_loan']);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Could not load sale: $e');
    }
  }

  String _numberText(dynamic value) {
    if (value == null) return '0';
    final number = double.tryParse(value.toString());
    if (number == null) return value.toString();
    if (number == number.roundToDouble()) return number.toInt().toString();
    return number.toString();
  }

  Future<String?> _showSearchSelector({
    required String title,
    required List<Map<String, dynamic>> items,
    required String nameKey,
    required String codeKey,
    bool showMagala = false,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _SearchSelectorSheet(
        title: title,
        items: items,
        nameKey: nameKey,
        codeKey: codeKey,
        showMagala: showMagala,
      ),
    );
  }

  String _farmerDisplayName() {
    if (_selectedFarmerId == null) return 'Select farmer';
    for (final farmer in _farmers) {
      if (farmer['id'].toString() == _selectedFarmerId) {
        return '${farmer['full_name']} (${farmer['farmer_code']})';
      }
    }
    return 'Select farmer';
  }

  String _sellerDisplayName() {
    if (_selectedSellerId == null) return 'Select seller';
    for (final seller in _sellers) {
      if (seller['id'].toString() == _selectedSellerId) {
        return '${seller['full_name']} (${seller['seller_code']})';
      }
    }
    return 'Select seller';
  }

  String _buyerDisplayName(String? buyerId) {
    if (buyerId == null) return 'Select buyer';
    for (final buyer in _buyers) {
      if (buyer['id'].toString() == buyerId) {
        if (buyer['is_magala'] == true) {
          return '${buyer['group_name']} (Magala)';
        }
        return '${buyer['group_name']} (${buyer['buyer_code']})';
      }
    }
    return 'Select buyer';
  }

  void _addBuyer() {
    setState(() {
      _saleBuyers.add({
        'buyer_id': null,
        'paid_amount': TextEditingController(),
        'lines': <Map<String, dynamic>>[],
      });
    });
  }

  void _removeBuyer(int index) {
    final buyer = _saleBuyers[index];
    final paid = buyer['paid_amount'];
    if (paid is TextEditingController) paid.dispose();
    for (final line in buyer['lines']) {
      line['bundle_count'].dispose();
      line['price_per_bundle'].dispose();
    }
    setState(() => _saleBuyers.removeAt(index));
  }

  void _addPriceLine(int buyerIndex) {
    setState(() {
      _saleBuyers[buyerIndex]['lines'].add({
        'bundle_count': TextEditingController(),
        'price_per_bundle': TextEditingController(),
      });
    });
  }

  void _removePriceLine(int buyerIndex, int lineIndex) {
    final line = _saleBuyers[buyerIndex]['lines'][lineIndex];
    line['bundle_count'].dispose();
    line['price_per_bundle'].dispose();
    setState(() => _saleBuyers[buyerIndex]['lines'].removeAt(lineIndex));
  }

  int _buyerBundles(Map<String, dynamic> buyer) {
    int total = 0;
    for (final line in buyer['lines']) {
      total += int.tryParse(line['bundle_count'].text.trim()) ?? 0;
    }
    return total;
  }

  double _buyerTotal(Map<String, dynamic> buyer) {
    double total = 0;
    for (final line in buyer['lines']) {
      final bundles = int.tryParse(line['bundle_count'].text.trim()) ?? 0;
      final price = double.tryParse(line['price_per_bundle'].text.trim()) ?? 0;
      total += bundles * price;
    }
    return total;
  }

  int get _calculatedBundles => _saleBuyers.fold(0, (sum, buyer) => sum + _buyerBundles(buyer));

  double get _totalSales => _saleBuyers.fold(0, (sum, buyer) => sum + _buyerTotal(buyer));

  double get _commission => _totalSales * 0.10;

  double get _advanceLoan => double.tryParse(_advanceLoanController.text.trim()) ?? 0;

  double get _farmerAmount => (_totalSales * 0.90) - _advanceLoan;

  String _formatAmount(double value) => '${value.toStringAsFixed(2)} Birr';

  Future<void> _pickDate() async {
    final initial = _selectedDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveChanges() async {
    final bundles = int.tryParse(_totalBundlesController.text.trim());

    if (_selectedFarmerId == null) return _showMessage('Select a farmer.');
    if (_selectedSellerId == null) return _showMessage('Select a seller.');
    if (_selectedDate == null) return _showMessage('Select a sale date.');
    if (bundles == null || bundles <= 0) return _showMessage('Enter a valid total Kilo.');
    if (_saleBuyers.isEmpty) return _showMessage('Add at least one buyer.');
    if (_calculatedBundles != bundles) {
      return _showMessage('Kilo mismatch: entered $bundles, but buyer price lines contain $_calculatedBundles.');
    }
    if (_totalSales <= 0) return _showMessage('Total sales must be greater than zero.');
    if (_advanceLoan < 0) return _showMessage('Advance loan cannot be negative.');
    if (_advanceLoan > _totalSales * 0.90) return _showMessage('Advance loan cannot exceed farmer amount.');

    for (int i = 0; i < _saleBuyers.length; i++) {
      final buyer = _saleBuyers[i];
      if (buyer['buyer_id'] == null) return _showMessage('Select Buyer ${i + 1}.');
      if (buyer['lines'].isEmpty) return _showMessage('Add at least one price line for Buyer ${i + 1}.');

      for (final line in buyer['lines']) {
        final kilo = int.tryParse(line['bundle_count'].text.trim());
        final price = double.tryParse(line['price_per_bundle'].text.trim());
        if (kilo == null || kilo <= 0) return _showMessage('Enter a valid whole-number kilo for Buyer ${i + 1}.');
        if (price == null || price < 0) return _showMessage('Enter a valid price for Buyer ${i + 1}.');
      }

      final total = _buyerTotal(buyer);
      final paid = double.tryParse(buyer['paid_amount'].text.trim()) ?? 0;
      if (paid < 0) return _showMessage('Paid amount cannot be negative.');
      if (paid > total) return _showMessage('Paid amount cannot exceed Buyer ${i + 1} total.');
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _showReasonError = true);
      _showMessage('Enter the reason for correcting this sale.');
      return;
    }
    setState(() => _showReasonError = false);

    final buyersJson = _saleBuyers.map((buyer) {
      return {
        'buyer_id': buyer['buyer_id'],
        'paid_amount': double.tryParse(buyer['paid_amount'].text.trim()) ?? 0,
        'lines': buyer['lines'].map((line) => {
          'bundle_count': int.parse(line['bundle_count'].text.trim()),
          'price_per_bundle': double.parse(line['price_per_bundle'].text.trim()),
        }).toList(),
      };
    }).toList();

    final confirmed = await _showConfirmation(bundles, reason);
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final result = await _supabase.rpc(
        'update_sale',
        params: {
          'p_sale_id': widget.saleId,
          'p_farmer_id': _selectedFarmerId,
          'p_seller_id': _selectedSellerId,
          'p_sale_date': _dateOnly(_selectedDate!),
          'p_total_bundles': bundles,
          'p_advance_loan': _advanceLoan,
          'p_buyers': buyersJson,
          'p_reason': reason,
        },
      );

      if (!mounted) return;
      final data = Map<String, dynamic>.from(result as Map);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sale Corrected'),
          content: Text(
            'Transaction ${data['transaction_code'] ?? _transactionCode} was updated successfully.\n\n'
            'Total Sales: ${_formatAmount(_totalSales)}\n'
            'Commission: ${_formatAmount(_commission)}\n'
            'Farmer Amount: ${_formatAmount(_farmerAmount)}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showMessage('Could not correct sale: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<bool> _showConfirmation(int bundles, String reason) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm Sale Correction'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'This will replace the saved sale details and recalculate the affected balances.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  Text('Transaction: $_transactionCode'),
                  Text('Farmer: ${_farmerDisplayName()}'),
                  Text('Seller: ${_sellerDisplayName()}'),
                  Text('Date: ${_dateOnly(_selectedDate!)}'),
                  Text('Total Kilo: $bundles'),
                  Text('Total Sales: ${_formatAmount(_totalSales)}'),
                  Text('Commission: ${_formatAmount(_commission)}'),
                  Text('Advance Loan: ${_formatAmount(_advanceLoan)}'),
                  Text('Farmer Amount: ${_formatAmount(_farmerAmount)}'),
                  const SizedBox(height: 12),
                  const Text('Correction reason:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(reason),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Confirm Correction')),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Sale')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Sale')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Correct Sale $_transactionCode',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final id = await _showSearchSelector(
                  title: 'Farmer',
                  items: _farmers,
                  nameKey: 'full_name',
                  codeKey: 'farmer_code',
                );
                if (id != null && mounted) setState(() => _selectedFarmerId = id);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Farmer', prefixIcon: Icon(Icons.agriculture_outlined), border: OutlineInputBorder()),
                child: Text(_farmerDisplayName()),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final id = await _showSearchSelector(
                  title: 'Seller',
                  items: _sellers,
                  nameKey: 'full_name',
                  codeKey: 'seller_code',
                );
                if (id != null && mounted) setState(() => _selectedSellerId = id);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Seller', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                child: Text(_sellerDisplayName()),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Sale Date', prefixIcon: Icon(Icons.calendar_today_outlined), border: OutlineInputBorder()),
                child: Text(_selectedDate == null ? 'Select date' : _dateOnly(_selectedDate!)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _totalBundlesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total Kilo', prefixIcon: Icon(Icons.inventory_2_outlined), border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _advanceLoanController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Advance Loan', prefixIcon: Icon(Icons.payments_outlined), border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Buyer Entries', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                OutlinedButton.icon(onPressed: _addBuyer, icon: const Icon(Icons.add), label: const Text('Add Buyer')),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(_saleBuyers.length, (buyerIndex) {
              final buyer = _saleBuyers[buyerIndex];
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final id = await _showSearchSelector(
                                  title: 'Buyer',
                                  items: _buyers,
                                  nameKey: 'group_name',
                                  codeKey: 'buyer_code',
                                  showMagala: true,
                                );
                                if (id != null && mounted) setState(() => buyer['buyer_id'] = id);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Buyer', border: OutlineInputBorder()),
                                child: Text(_buyerDisplayName(buyer['buyer_id'])),
                              ),
                            ),
                          ),
                          IconButton(onPressed: () => _removeBuyer(buyerIndex), icon: const Icon(Icons.delete_outline)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Price Lines', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...List.generate((buyer['lines'] as List).length, (lineIndex) {
                        final line = buyer['lines'][lineIndex];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: line['bundle_count'],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Kilo', border: OutlineInputBorder()),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: line['price_per_bundle'],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Price / Kilo', border: OutlineInputBorder()),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              IconButton(onPressed: () => _removePriceLine(buyerIndex, lineIndex), icon: const Icon(Icons.remove_circle_outline)),
                            ],
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(onPressed: () => _addPriceLine(buyerIndex), icon: const Icon(Icons.add), label: const Text('Add Price Line')),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: buyer['paid_amount'],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Paid Amount', prefixIcon: Icon(Icons.check_circle_outline), border: OutlineInputBorder()),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text('Buyer Total: ${_formatAmount(_buyerTotal(buyer))}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Unpaid: ${_formatAmount(_buyerTotal(buyer) - (double.tryParse(buyer['paid_amount'].text.trim()) ?? 0))}'),
                    ],
                  ),
                ),
              );
            }),
            const Divider(height: 28),
            Text('New Sale Total: ${_formatAmount(_totalSales)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Commission: ${_formatAmount(_commission)}'),
            Text('Farmer Amount: ${_formatAmount(_farmerAmount)}'),
            const SizedBox(height: 18),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Correction Reason',
                hintText: 'Example: Wrong price entered for Ali Group',
                prefixIcon: const Icon(Icons.info_outline),
                border: const OutlineInputBorder(),
                errorText: _showReasonError ? 'Correction reason is required' : null,
              ),
              onChanged: (_) {
                if (_showReasonError) setState(() => _showReasonError = false);
              },
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving Correction...' : 'Save Correction'),
            ),
            const SizedBox(height: 10),
            Text(
              'A successful correction is recorded in the sale edit history for audit purposes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSelectorSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final String nameKey;
  final String codeKey;
  final bool showMagala;

  const _SearchSelectorSheet({
    required this.title,
    required this.items,
    required this.nameKey,
    required this.codeKey,
    required this.showMagala,
  });

  @override
  State<_SearchSelectorSheet> createState() => _SearchSelectorSheetState();
}

class _SearchSelectorSheetState extends State<_SearchSelectorSheet> {
  late final TextEditingController _searchController;
  late List<Map<String, dynamic>> _filteredItems;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredItems = List.from(widget.items);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filteredItems = widget.items.where((item) {
        if (q.isEmpty) return true;
        final name = (item[widget.nameKey] ?? '').toString().toLowerCase();
        final code = (item[widget.codeKey] ?? '').toString().toLowerCase();
        final phone = (item['phone'] ?? '').toString().toLowerCase();
        final magala = widget.showMagala && item['is_magala'] == true;
        return name.contains(q) || code.contains(q) || phone.contains(q) || (magala && 'magala'.contains(q));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.80,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            children: [
              Text('Select ${widget.title}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _search,
                decoration: InputDecoration(
                  labelText: 'Search ${widget.title}',
                  hintText: 'Name, code, or phone',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _search('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filteredItems.isEmpty
                    ? Center(child: Text('No ${widget.title} found'))
                    : ListView.separated(
                        itemCount: _filteredItems.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final name = item[widget.nameKey]?.toString() ?? 'Unknown';
                          final code = item[widget.codeKey]?.toString() ?? '';
                          final phone = item['phone']?.toString() ?? '';
                          final isMagala = widget.showMagala && item['is_magala'] == true;
                          final inactive = item.containsKey('is_active') && item['is_active'] == false;
                          return ListTile(
                            leading: CircleAvatar(child: Icon(isMagala ? Icons.storefront_outlined : Icons.person_outline)),
                            title: Text(isMagala ? '$name (Magala)' : name),
                            subtitle: Text([code, phone, if (inactive) 'Inactive'].where((e) => e.isNotEmpty).join(' • ')),
                            onTap: () => Navigator.of(context).pop(item['id'].toString()),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
