import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'seller_transaction_history.dart';

class SellerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> seller;

  const SellerProfileScreen({super.key, required this.seller});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final _supabase = Supabase.instance.client;

  late Map<String, dynamic> _seller;
  bool _isLoading = false;
  int _historyRefreshTrigger = 0;

  @override
  void initState() {
    super.initState();
    _seller = Map<String, dynamic>.from(widget.seller);
    _reloadSeller();
  }

  double get _debt =>
      double.tryParse(_seller['current_debt']?.toString() ?? '0') ?? 0;

  String _money(double value) => '${value.toStringAsFixed(2)} Birr';

  Future<void> _reloadSeller() async {
    try {
      final data = await _supabase
          .from('sellers')
          .select('id, seller_code, full_name, phone, current_debt, is_active')
          .eq('id', _seller['id'])
          .single();

      if (!mounted) return;

      setState(() {
        _seller = Map<String, dynamic>.from(data);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Could not reload seller: $e'),
        ),
      );
    }
  }

  Future<void> _refreshAll() async {
    await _reloadSeller();
    if (!mounted) return;
    setState(() {
      _historyRefreshTrigger++;
    });
  }

  Future<void> _editSeller() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _EditSellerDialog(seller: _seller, supabase: _supabase);
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: const Text('Seller profile updated successfully'),
        ),
      );
      await _reloadSeller();
    }
  }

  Future<void> _deleteSeller() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Seller'),
          content: const Text(
            'The seller will be removed from the active seller list. '
            'Existing sales and financial history will remain.',
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
          .from('sellers')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _seller['id']);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete seller: $e')),
      );
    }
  }

  Future<void> _payDebt() async {
    if (_debt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This seller has no outstanding debt.')),
      );
      return;
    }

    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return _PaySellerDebtDialog(currentDebt: _debt);
      },
    );

    if (amount == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _supabase.rpc(
        'record_seller_debt_payment',
        params: {
          'p_seller_id': _seller['id'],
          'p_amount': amount,
        },
      );

      if (!mounted) return;

      await _refreshAll();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text('Payment of ${_money(amount)} recorded successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Could not record payment: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _adjustDebt() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return _AdjustSellerDebtDialog(currentDebt: _debt);
      },
    );

    if (result == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _supabase.rpc(
        'adjust_seller_debt',
        params: {
          'p_seller_id': _seller['id'],
          'p_new_balance': result['new_balance'],
          'p_reason': result['reason'],
        },
      );

      if (!mounted) return;

      await _refreshAll();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: const Text('Seller debt adjusted successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Could not adjust debt: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellerId = _seller['id'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Profile'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _editSeller,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _isLoading ? null : _deleteSeller,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                const CircleAvatar(
                  radius: 45,
                  child: Icon(Icons.person_outline, size: 45),
                ),
                const SizedBox(height: 16),
                Text(
                  _seller['full_name'] ?? 'Unknown',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Seller Code'),
                        subtitle: Text(_seller['seller_code'] ?? 'No code'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Full Name'),
                        subtitle: Text(_seller['full_name'] ?? 'Unknown'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('Phone'),
                        subtitle: Text(_seller['phone'] ?? 'No phone number'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _debt > 0
                                  ? Colors.red.shade100
                                  : Colors.green.shade100,
                              child: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: _debt > 0
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Money Owed to Brokerage',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _money(_debt),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _debt > 0 ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _debt > 0
                              ? 'This includes paid amounts collected from Magala and any debt increases from adjustments.'
                              : 'No outstanding seller debt.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _debt > 0 && !_isLoading ? _payDebt : null,
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Pay Debt'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _adjustDebt,
                            icon: const Icon(Icons.edit_note_outlined),
                            label: const Text('Adjust Debt'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SellerTransactionHistory(
                  key: ValueKey('${sellerId}_$_historyRefreshTrigger'),
                  sellerId: sellerId,
                  refreshTrigger: _historyRefreshTrigger,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditSellerDialog extends StatefulWidget {
  final Map<String, dynamic> seller;
  final SupabaseClient supabase;

  const _EditSellerDialog({required this.seller, required this.supabase});

  @override
  State<_EditSellerDialog> createState() => _EditSellerDialogState();
}

class _EditSellerDialogState extends State<_EditSellerDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.seller['full_name']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.seller['phone']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the seller name.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.supabase
          .from('sellers')
          .update({
            'full_name': name,
            'phone': phone.isEmpty ? null : phone,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.seller['id']);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update seller: $e')),
      );
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Seller'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _PaySellerDebtDialog extends StatefulWidget {
  final double currentDebt;

  const _PaySellerDebtDialog({required this.currentDebt});

  @override
  State<_PaySellerDebtDialog> createState() => _PaySellerDebtDialogState();
}

class _PaySellerDebtDialogState extends State<_PaySellerDebtDialog> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _continue() {
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid payment amount.')),
      );
      return;
    }

    if (amount > widget.currentDebt) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment cannot exceed the seller debt.')),
      );
      return;
    }

    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pay Seller Debt'),
      content: TextField(
        controller: _amountController,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Payment amount',
          suffixText: 'Birr',
          hintText: 'Current debt: ${widget.currentDebt.toStringAsFixed(2)} Birr',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _continue, child: const Text('Continue')),
      ],
    );
  }
}

class _AdjustSellerDebtDialog extends StatefulWidget {
  final double currentDebt;

  const _AdjustSellerDebtDialog({required this.currentDebt});

  @override
  State<_AdjustSellerDebtDialog> createState() => _AdjustSellerDebtDialogState();
}

class _AdjustSellerDebtDialogState extends State<_AdjustSellerDebtDialog> {
  late final TextEditingController _balanceController;
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController(
      text: widget.currentDebt.toStringAsFixed(2),
    );
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _adjust() {
    final newBalance = double.tryParse(_balanceController.text.trim());
    final reason = _reasonController.text.trim();

    if (newBalance == null || newBalance < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid debt balance.')),
      );
      return;
    }

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a reason for the adjustment.')),
      );
      return;
    }

    Navigator.of(context).pop({
      'new_balance': newBalance,
      'reason': reason,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adjust Debt'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'New debt balance',
                suffixText: 'Birr',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Why is the debt being adjusted?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _adjust, child: const Text('Adjust')),
      ],
    );
  }
}
