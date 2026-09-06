import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'buyer_transaction_history.dart';

class BuyerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> buyer;

  const BuyerProfileScreen({super.key, required this.buyer});

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  final _supabase = Supabase.instance.client;

  late Map<String, dynamic> _buyer;

  bool _isLoading = false;

  int _historyRefreshTrigger = 0;

  @override
  void initState() {
    super.initState();

    _buyer = Map<String, dynamic>.from(widget.buyer);
  }

  // ================================================================
  // CURRENT DEBT
  // ================================================================

  double get _debt {
    return double.tryParse(_buyer['current_debt']?.toString() ?? '0') ?? 0;
  }

  // ================================================================
  // MONEY FORMAT
  // ================================================================

  String _money(double value) {
    return '${value.toStringAsFixed(2)} Birr';
  }

  // ================================================================
  // RELOAD BUYER
  // ================================================================

  Future<void> _reloadBuyer() async {
    try {
      final data = await _supabase
          .from('buyers')
          .select(
            'id, buyer_code, group_name, phone, '
            'current_debt, is_active, is_magala',
          )
          .eq('id', _buyer['id'])
          .single();

      if (!mounted) return;

      setState(() {
        _buyer = Map<String, dynamic>.from(data);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Could not reload buyer: $e'),
        ),
      );
    }
  }

  // ================================================================
  // REFRESH ALL
  // ================================================================

  Future<void> _refreshAll() async {
    await _reloadBuyer();

    if (!mounted) return;

    setState(() {
      _historyRefreshTrigger++;
    });
  }

  // ================================================================
  // EDIT BUYER
  // ================================================================

  Future<void> _editBuyer() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _EditBuyerDialog(buyer: _buyer, supabase: _supabase);
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: const Text('Buyer profile updated successfully'),
        ),
      );

      await _reloadBuyer();
    }
  }

  // ================================================================
  // DELETE BUYER
  // ================================================================

  Future<void> _deleteBuyer() async {
    final buyerName = _buyer['group_name']?.toString() ?? 'this buyer';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Buyer'),
          content: Text(
            'Are you sure you want to delete "$buyerName"?\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _supabase.from('buyers').delete().eq('id', _buyer['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text('Buyer "$buyerName" deleted successfully'),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Could not delete buyer: $e'),
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

  // ================================================================
  // PAY DEBT
  // ================================================================

  Future<void> _payDebt() async {
    if (_debt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This buyer has no outstanding debt.')),
      );

      return;
    }

    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return _PayBuyerDebtDialog(currentDebt: _debt);
      },
    );

    if (amount == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _supabase.rpc(
        'record_buyer_debt_payment',
        params: {'p_buyer_id': _buyer['id'], 'p_amount': amount},
      );

      if (!mounted) return;

      await _reloadBuyer();

      if (!mounted) return;

      setState(() {
        _historyRefreshTrigger++;
      });

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

  // ================================================================
  // ADJUST DEBT
  // ================================================================

  Future<void> _adjustDebt() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return _AdjustBuyerDebtDialog(currentDebt: _debt);
      },
    );

    if (result == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _supabase.rpc(
        'adjust_buyer_debt',
        params: {
          'p_buyer_id': _buyer['id'],
          'p_new_balance': result['new_balance'],
          'p_reason': result['reason'],
        },
      );

      if (!mounted) return;

      await _reloadBuyer();

      if (!mounted) return;

      setState(() {
        _historyRefreshTrigger++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: const Text('Buyer debt adjusted successfully'),
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

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final buyerId = _buyer['id'];
    final isMagala = _buyer['is_magala'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyer Profile'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _editBuyer,
            tooltip: 'Edit Buyer',
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _isLoading ? null : _deleteBuyer,
            tooltip: 'Delete Buyer',
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ======================================================
                  // AVATAR
                  // ======================================================
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.green.shade100,
                    child: Icon(
                      isMagala
                          ? Icons.storefront_outlined
                          : Icons.groups_outlined,
                      size: 45,
                      color: Colors.green.shade700,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ======================================================
                  // BUYER GROUP NAME
                  // ======================================================
                  Text(
                    _buyer['group_name']?.toString() ?? 'Unknown',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (isMagala) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Chip(
                        backgroundColor: Colors.green.shade100,
                        label: Text(
                          'MAGALA',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ======================================================
                  // CURRENT DEBT
                  // ======================================================
                  Card(
                    elevation: 3,
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade600, Colors.teal.shade600],
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Current Debt',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            _money(_debt),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ======================================================
                  // BUYER INFORMATION
                  // ======================================================
                  Card(
                    elevation: 2,
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(
                              Icons.badge_outlined,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          title: const Text('Buyer ID'),
                          subtitle: Text(
                            _buyer['buyer_code']?.toString() ?? 'No ID',
                          ),
                        ),

                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.shade100,
                            child: Icon(
                              Icons.groups_outlined,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          title: const Text('Group Name'),
                          subtitle: Text(
                            _buyer['group_name']?.toString() ?? 'Unknown',
                          ),
                        ),

                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.shade100,
                            child: Icon(
                              Icons.phone_outlined,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          title: const Text('Phone'),
                          subtitle: Text(
                            _buyer['phone']?.toString() ?? 'No phone number',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ======================================================
                  // PAY DEBT
                  // ======================================================
                  if (!isMagala)
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _payDebt,
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text(
                          'Pay Debt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  if (!isMagala) const SizedBox(height: 12),

                  // ======================================================
                  // ADJUST DEBT
                  // ======================================================
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _adjustDebt,
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text(
                        'Adjust Debt',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ======================================================
                  // TRANSACTION HISTORY
                  // ======================================================
                  BuyerTransactionHistory(
                    key: ValueKey('${buyerId}_$_historyRefreshTrigger'),
                    buyerId: buyerId,
                    refreshTrigger: _historyRefreshTrigger,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

// ====================================================================
// EDIT BUYER DIALOG
// ====================================================================

class _EditBuyerDialog extends StatefulWidget {
  final Map<String, dynamic> buyer;
  final SupabaseClient supabase;

  const _EditBuyerDialog({required this.buyer, required this.supabase});

  @override
  State<_EditBuyerDialog> createState() => _EditBuyerDialogState();
}

class _EditBuyerDialogState extends State<_EditBuyerDialog> {
  late final TextEditingController _groupNameController;
  late final TextEditingController _phoneController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _groupNameController = TextEditingController(
      text: widget.buyer['group_name']?.toString() ?? '',
    );

    _phoneController = TextEditingController(
      text: widget.buyer['phone']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    final groupName = _groupNameController.text.trim();

    final phone = _phoneController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the buyer group name')),
      );

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.supabase
          .from('buyers')
          .update({
            'group_name': groupName,
            'phone': phone.isEmpty ? null : phone,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.buyer['id']);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Could not update buyer: $e'),
        ),
      );

      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Buyer'),

      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _groupNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Group name',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
        ],
      ),

      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('Cancel'),
        ),

        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ====================================================================
// PAY DEBT DIALOG
// ====================================================================

class _PayBuyerDebtDialog extends StatefulWidget {
  final double currentDebt;

  const _PayBuyerDebtDialog({required this.currentDebt});

  @override
  State<_PayBuyerDebtDialog> createState() => _PayBuyerDebtDialogState();
}

class _PayBuyerDebtDialogState extends State<_PayBuyerDebtDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  String _money(double value) {
    return '${value.toStringAsFixed(2)} Birr';
  }

  void _continue() {
    final value = double.tryParse(_controller.text.trim());

    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid payment amount.')),
      );

      return;
    }

    if (value > widget.currentDebt) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment cannot exceed current debt '
            '(${_money(widget.currentDebt)}).',
          ),
        ),
      );

      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pay Debt'),

      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Payment amount',
          suffixText: 'Birr',
          hintText: 'Current debt: ${_money(widget.currentDebt)}',
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),

        FilledButton(onPressed: _continue, child: const Text('Continue')),
      ],
    );
  }
}

// ====================================================================
// ADJUST DEBT DIALOG
// ====================================================================

class _AdjustBuyerDebtDialog extends StatefulWidget {
  final double currentDebt;

  const _AdjustBuyerDebtDialog({required this.currentDebt});

  @override
  State<_AdjustBuyerDebtDialog> createState() => _AdjustBuyerDebtDialogState();
}

class _AdjustBuyerDebtDialogState extends State<_AdjustBuyerDebtDialog> {
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

    Navigator.of(context).pop({'new_balance': newBalance, 'reason': reason});
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),

        FilledButton(onPressed: _adjust, child: const Text('Adjust')),
      ],
    );
  }
}
