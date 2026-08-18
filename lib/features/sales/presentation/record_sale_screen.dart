import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecordSaleScreen extends StatefulWidget {
  const RecordSaleScreen({super.key});

  @override
  State<RecordSaleScreen> createState() => _RecordSaleScreenState();
}

class _RecordSaleScreenState extends State<RecordSaleScreen> {
  final _supabase = Supabase.instance.client;

  final _totalBundlesController = TextEditingController();
  final _advanceLoanController = TextEditingController();

  List<Map<String, dynamic>> _farmers = [];
  List<Map<String, dynamic>> _sellers = [];
  List<Map<String, dynamic>> _buyers = [];

  String? _selectedFarmerId;
  String? _selectedSellerId;

  bool _isLoading = true;
  bool _isSaving = false;

  // Each item represents one buyer.
  final List<Map<String, dynamic>> _saleBuyers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _supabase
            .from('farmers')
            .select('id, farmer_code, full_name')
            .eq('is_active', true)
            .order('full_name'),

        _supabase
            .from('sellers')
            .select('id, seller_code, full_name')
            .eq('is_active', true)
            .order('full_name'),

        _supabase
            .from('buyers')
            .select('id, buyer_code, group_name, is_magala')
            .eq('is_active', true)
            .order('group_name'),
      ]);

      if (!mounted) return;

      setState(() {
        _farmers =
            List<Map<String, dynamic>>.from(results[0]);

        _sellers =
            List<Map<String, dynamic>>.from(results[1]);

        _buyers =
            List<Map<String, dynamic>>.from(results[2]);

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Could not load data: $e');
    }
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

    for (final line in buyer['lines']) {
      line['bundle_count'].dispose();
      line['price_per_bundle'].dispose();
    }

    buyer['paid_amount'].dispose();

    setState(() {
      _saleBuyers.removeAt(index);
    });
  }

  void _addPriceLine(int buyerIndex) {
    setState(() {
      _saleBuyers[buyerIndex]['lines'].add({
        'bundle_count': TextEditingController(),
        'price_per_bundle': TextEditingController(),
      });
    });
  }

  void _removePriceLine(
    int buyerIndex,
    int lineIndex,
  ) {
    final line =
        _saleBuyers[buyerIndex]['lines'][lineIndex];

    line['bundle_count'].dispose();
    line['price_per_bundle'].dispose();

    setState(() {
      _saleBuyers[buyerIndex]['lines']
          .removeAt(lineIndex);
    });
  }

  int _buyerBundles(Map<String, dynamic> buyer) {
    int total = 0;

    for (final line in buyer['lines']) {
      total +=
          int.tryParse(
                line['bundle_count'].text.trim(),
              ) ??
              0;
    }

    return total;
  }

  double _buyerTotal(Map<String, dynamic> buyer) {
    double total = 0;

    for (final line in buyer['lines']) {
      final bundles =
          int.tryParse(
                line['bundle_count'].text.trim(),
              ) ??
              0;

      final price =
          double.tryParse(
                line['price_per_bundle'].text.trim(),
              ) ??
              0;

      total += bundles * price;
    }

    return total;
  }

  int get _calculatedBundles {
    int total = 0;

    for (final buyer in _saleBuyers) {
      total += _buyerBundles(buyer);
    }

    return total;
  }

  double get _totalSales {
    double total = 0;

    for (final buyer in _saleBuyers) {
      total += _buyerTotal(buyer);
    }

    return total;
  }

  double get _commission {
    return _totalSales * 0.10;
  }

  double get _farmerAmount {
    return (_totalSales * 0.90) -
        _advanceLoan;
  }

  double get _advanceLoan {
    return double.tryParse(
          _advanceLoanController.text.trim(),
        ) ??
        0;
  }

  @override
  void dispose() {
    _totalBundlesController.dispose();
    _advanceLoanController.dispose();

    for (final buyer in _saleBuyers) {
      buyer['paid_amount'].dispose();

      for (final line in buyer['lines']) {
        line['bundle_count'].dispose();
        line['price_per_bundle'].dispose();
      }
    }

    super.dispose();
  }

  Future<void> _saveSale() async {
    final enteredBundles =
        int.tryParse(
          _totalBundlesController.text.trim(),
        );

    if (_selectedFarmerId == null) {
      _showMessage('Select a farmer.');
      return;
    }

    if (_selectedSellerId == null) {
      _showMessage('Select a seller.');
      return;
    }

    if (enteredBundles == null ||
        enteredBundles <= 0) {
      _showMessage(
        'Enter a valid total Kilo.',
      );
      return;
    }

    if (_saleBuyers.isEmpty) {
      _showMessage(
        'Add at least one buyer.',
      );
      return;
    }

    if (_calculatedBundles != enteredBundles) {
      _showMessage(
        'Kilo mismatch: entered $enteredBundles, '
        'but buyer price lines contain $_calculatedBundles.',
      );
      return;
    }

    if (_totalSales <= 0) {
      _showMessage(
        'Total sales must be greater than zero.',
      );
      return;
    }

    if (_advanceLoan < 0) {
      _showMessage(
        'Advance loan cannot be negative.',
      );
      return;
    }

    if (_advanceLoan >
        (_totalSales * 0.90)) {
      _showMessage(
        'Advance loan cannot exceed farmer amount.',
      );
      return;
    }

    for (int i = 0;
        i < _saleBuyers.length;
        i++) {
      final buyer = _saleBuyers[i];

      if (buyer['buyer_id'] == null) {
        _showMessage(
          'Select Buyer ${i + 1}.',
        );
        return;
      }

      if (buyer['lines'].isEmpty) {
        _showMessage(
          'Add at least one price line for Buyer ${i + 1}.',
        );
        return;
      }

      final buyerTotal =
          _buyerTotal(buyer);

      final paid =
          double.tryParse(
                buyer['paid_amount']
                    .text
                    .trim(),
              ) ??
              0;

      if (paid < 0) {
        _showMessage(
          'Paid amount cannot be negative.',
        );
        return;
      }

      if (paid > buyerTotal) {
        _showMessage(
          'Paid amount cannot exceed buyer total.',
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final buyersJson =
          _saleBuyers.map((buyer) {
        return {
          'buyer_id': buyer['buyer_id'],
          'paid_amount':
              double.tryParse(
                    buyer['paid_amount']
                        .text
                        .trim(),
                  ) ??
                  0,
          'lines':
              buyer['lines'].map((line) {
            return {
              'bundle_count':
                  int.parse(
                    line['bundle_count']
                        .text
                        .trim(),
                  ),
              'price_per_bundle':
                  double.parse(
                    line['price_per_bundle']
                        .text
                        .trim(),
                  ),
            };
          }).toList(),
        };
      }).toList();

      final result =
          await _supabase.rpc(
        'record_sale',
        params: {
          'p_farmer_id':
              _selectedFarmerId,
          'p_seller_id':
              _selectedSellerId,
          'p_total_bundles':
              enteredBundles,
          'p_advance_loan':
              _advanceLoan,
          'p_buyers':
              buyersJson,
        },
      );

      if (!mounted) return;

      await _showSaleSuccess(result);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not save sale: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showSaleSuccess(
    dynamic result,
  ) async {
    final data =
        Map<String, dynamic>.from(result);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Sale Recorded Successfully',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Transaction: '
                '${data['transaction_code']}',
              ),
              const SizedBox(height: 12),
              Text(
                'Total Sales: '
                '${data['total_sales']} Birr',
              ),
              Text(
                'Commission: '
                '${data['commission']} Birr',
              ),
              Text(
                'Farmer Amount: '
                '${data['farmer_amount']} Birr',
              ),
              Text(
                'New Farmer Balance: '
                '${data['new_farmer_balance']} Birr',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Record Sale'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Sale'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sale Information',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedFarmerId,
              decoration: const InputDecoration(
                labelText: 'Farmer',
                prefixIcon:
                    Icon(Icons.agriculture_outlined),
                border: OutlineInputBorder(),
              ),
              items: _farmers.map((farmer) {
                return DropdownMenuItem<String>(
                  value: farmer['id'],
                  child: Text(
                    '${farmer['full_name']} '
                    '(${farmer['farmer_code']})',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFarmerId = value;
                });
              },
            ),

            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _selectedSellerId,
              decoration: const InputDecoration(
                labelText: 'Seller',
                prefixIcon:
                    Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              items: _sellers.map((seller) {
                return DropdownMenuItem<String>(
                  value: seller['id'],
                  child: Text(
                    '${seller['full_name']} '
                    '(${seller['seller_code']})',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSellerId = value;
                });
              },
            ),

            const SizedBox(height: 14),

            TextField(
              controller:
                  _totalBundlesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Kilo',
                prefixIcon:
                    Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),

            const SizedBox(height: 28),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Buyers',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Kilo: $_calculatedBundles',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ...List.generate(
              _saleBuyers.length,
              (buyerIndex) {
                return _buildBuyerCard(
                  buyerIndex,
                );
              },
            ),

            OutlinedButton.icon(
              onPressed: _addBuyer,
              icon: const Icon(
                Icons.person_add_outlined,
              ),
              label: const Text(
                'Add Buyer',
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller:
                  _advanceLoanController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Advance Loan',
                suffixText: 'Birr',
                prefixIcon:
                    Icon(Icons.money_off_outlined),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),

            const SizedBox(height: 20),

            _buildSummary(),

            const SizedBox(height: 24),

            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed:
                    _isSaving ? null : _saveSale,
                icon: const Icon(
                  Icons.save_outlined,
                ),
                label: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'SAVE SALE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyerCard(int buyerIndex) {
    final buyer =
        _saleBuyers[buyerIndex];

    return Card(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Buyer ${buyerIndex + 1}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      _removeBuyer(
                    buyerIndex,
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                ),
              ],
            ),

            DropdownButtonFormField<String>(
              value: buyer['buyer_id'],
              decoration: const InputDecoration(
                labelText: 'Buyer Group',
                border: OutlineInputBorder(),
              ),
              items: _buyers.map((item) {
                final magala =
                    item['is_magala'] == true;

                return DropdownMenuItem<String>(
                  value: item['id'],
                  child: Text(
                    magala
                        ? '${item['group_name']} (Magala)'
                        : '${item['group_name']} '
                          '(${item['buyer_code']})',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  buyer['buyer_id'] = value;
                });
              },
            ),

            const SizedBox(height: 14),

            ...List.generate(
              buyer['lines'].length,
              (lineIndex) {
                final line =
                    buyer['lines'][lineIndex];

                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller:
                              line['bundle_count'],
                          keyboardType:
                              TextInputType.number,
                          decoration:
                              const InputDecoration(
                            labelText: 'Kilo',
                            border:
                                OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            setState(() {});
                          },
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: TextField(
                          controller:
                              line['price_per_bundle'],
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Price / Kilo',
                            border:
                                OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            setState(() {});
                          },
                        ),
                      ),

                      IconButton(
                        onPressed: () =>
                            _removePriceLine(
                          buyerIndex,
                          lineIndex,
                        ),
                        icon: const Icon(
                          Icons
                              .remove_circle_outline,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            TextButton.icon(
              onPressed: () =>
                  _addPriceLine(
                buyerIndex,
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Price Line',
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller:
                  buyer['paid_amount'],
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
              decoration:
                  const InputDecoration(
                labelText: 'Paid Amount',
                suffixText: 'Birr',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),

            const SizedBox(height: 10),

            Text(
              'Buyer Total: '
              '${_buyerTotal(buyer).toStringAsFixed(2)} Birr',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(
              'Unpaid: '
              '${(_buyerTotal(buyer) -
                      (double.tryParse(
                            buyer['paid_amount']
                                .text
                                .trim(),
                          ) ??
                          0))
                  .toStringAsFixed(2)} Birr',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _summaryRow(
              'Total Kilo',
              '$_calculatedBundles',
            ),
            _summaryRow(
              'Total Sales',
              '${_totalSales.toStringAsFixed(2)} Birr',
            ),
            _summaryRow(
              'Commission (10%)',
              '${_commission.toStringAsFixed(2)} Birr',
            ),
            _summaryRow(
              'Farmer Amount (90%)',
              '${(_totalSales * 0.90).toStringAsFixed(2)} Birr',
            ),
            _summaryRow(
              'Advance Loan',
              '${_advanceLoan.toStringAsFixed(2)} Birr',
            ),
            const Divider(),
            _summaryRow(
              'Final Farmer Amount',
              '${_farmerAmount.toStringAsFixed(2)} Birr',
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight:
                  bold ? FontWeight.bold : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight:
                  bold ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
}