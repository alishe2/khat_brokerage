import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BuyerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> buyer;

  const BuyerProfileScreen({super.key, required this.buyer});

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  final _supabase = Supabase.instance.client;

  late Map<String, dynamic> _buyer;

  List<Map<String, dynamic>> _payments = [];

  bool _loadingPayments = true;

  @override
  void initState() {
    super.initState();
    _buyer = Map<String, dynamic>.from(widget.buyer);
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      final data = await _supabase
          .from('buyer_payments')
          .select('id, amount, payment_date, recorded_by, created_at')
          .eq('buyer_id', _buyer['id'])
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _payments = List<Map<String, dynamic>>.from(data);
        _loadingPayments = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingPayments = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load payments: $e')));
    }
  }

  double get _debt {
    final value = _buyer['current_debt'];
    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _recordPayment() async {
    final controller = TextEditingController();

    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Record Buyer Payment'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount paid',
              suffixText: 'Birr',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());

                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid amount')),
                  );
                  return;
                }

                if (value > _debt) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Payment cannot be greater than current debt',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Record'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (amount == null) return;

    try {
      await _supabase.rpc(
        'record_buyer_payment',
        params: {'p_buyer_id': _buyer['id'], 'p_amount': amount},
      );

      await _reloadBuyer();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not record payment: $e')));
    }
  }

  Future<void> _adjustDebt() async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    String adjustmentType = 'increase';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Adjust Debt'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: adjustmentType,
                      decoration: const InputDecoration(
                        labelText: 'Adjustment',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'increase',
                          child: Text('Increase debt'),
                        ),
                        DropdownMenuItem(
                          value: 'decrease',
                          child: Text('Decrease debt'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            adjustmentType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        suffixText: 'Birr',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Reason'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );

                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount')),
                      );
                      return;
                    }

                    if (adjustmentType == 'decrease' && amount > _debt) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Debt cannot be reduced below zero'),
                        ),
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop({
                      'amount': amount,
                      'type': adjustmentType,
                      'reason': reasonController.text.trim(),
                    });
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      amountController.dispose();
      reasonController.dispose();
    });

    if (result == null) return;

    try {
      final amount = result['amount'] as double;
      final type = result['type'] as String;

      final newDebt = type == 'increase' ? _debt + amount : _debt - amount;

      await _supabase
          .from('buyers')
          .update({
            'current_debt': newDebt,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _buyer['id']);

      await _reloadBuyer();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debt adjusted successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not adjust debt: $e')));
    }
  }

  Future<void> _reloadBuyer() async {
    final data = await _supabase
        .from('buyers')
        .select('id, buyer_code, group_name, phone, current_debt, is_magala')
        .eq('id', _buyer['id'])
        .single();

    if (!mounted) return;

    setState(() {
      _buyer = Map<String, dynamic>.from(data);
    });

    await _loadPayments();
  }

  Future<void> _editBuyer() async {
    final groupController = TextEditingController(text: _buyer['group_name']);
    final phoneController = TextEditingController(text: _buyer['phone'] ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Buyer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: groupController,
                decoration: const InputDecoration(labelText: 'Group name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (groupController.text.trim().isEmpty) {
                  return;
                }

                try {
                  await _supabase
                      .from('buyers')
                      .update({
                        'group_name': groupController.text.trim(),
                        'phone': phoneController.text.trim().isEmpty
                            ? null
                            : phoneController.text.trim(),
                        'updated_at': DateTime.now().toIso8601String(),
                      })
                      .eq('id', _buyer['id']);

                  if (!dialogContext.mounted) return;

                  Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Could not update buyer: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      groupController.dispose();
      phoneController.dispose();
    });

    if (saved == true) {
      await _reloadBuyer();
    }
  }

  Future<void> _deleteBuyer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Buyer'),
          content: const Text(
            'This buyer will be removed from the active buyer list. '
            'Existing sales history will remain.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('buyers')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _buyer['id']);

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete buyer: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMagala = _buyer['is_magala'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyer Profile'),
        actions: [
          IconButton(
            onPressed: _editBuyer,
            icon: const Icon(Icons.edit_outlined),
          ),
          if (!isMagala)
            IconButton(
              onPressed: _deleteBuyer,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reloadBuyer,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CircleAvatar(
              radius: 42,
              child: Icon(
                isMagala ? Icons.storefront_outlined : Icons.groups_outlined,
                size: 40,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _buyer['group_name'] ?? 'Unknown',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            if (isMagala) const Center(child: Chip(label: Text('MAGALA'))),

            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('Current Debt', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      '${_debt.toStringAsFixed(2)} Birr',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Buyer Code'),
                    subtitle: Text(_buyer['buyer_code'] ?? 'No code'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Phone'),
                    subtitle: Text(_buyer['phone'] ?? 'No phone number'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _recordPayment,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Record Payment'),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: _adjustDebt,
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Adjust Debt'),
            ),

            const SizedBox(height: 28),

            const Text(
              'Payment History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            if (_loadingPayments)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_payments.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No payments recorded yet.')),
                ),
              )
            else
              ..._payments.map(
                (payment) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.payments_outlined),
                    ),
                    title: Text(
                      '${payment['amount']} Birr',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(payment['payment_date'].toString()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
