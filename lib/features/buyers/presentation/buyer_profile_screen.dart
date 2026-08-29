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

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _buyer = Map<String, dynamic>.from(widget.buyer);
  }

  double get _debt {
    return double.tryParse(_buyer['current_debt']?.toString() ?? '0') ?? 0;
  }

  String _money(double value) {
    return '${value.toStringAsFixed(2)} Birr';
  }

  // ============================================================
  // REFRESH BUYER
  // ============================================================

  Future<void> _refreshBuyer() async {
    try {
      final data = await _supabase
          .from('buyers')
          .select()
          .eq('id', _buyer['id'])
          .single();

      if (!mounted) return;

      setState(() {
        _buyer = Map<String, dynamic>.from(data);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not refresh buyer: $e')));
    }
  }

  // ============================================================
  // EDIT BUYER
  // ============================================================

  Future<void> _editBuyer() async {
    final groupNameController = TextEditingController(
      text: _buyer['group_name']?.toString() ?? '',
    );

    final phoneController = TextEditingController(
      text: _buyer['phone']?.toString() ?? '',
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Buyer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: groupNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Group name',
                    hintText: 'Enter buyer group name',
                    prefixIcon: Icon(Icons.groups_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: 'Enter phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                final groupName = groupNameController.text.trim();
                final phone = phoneController.text.trim();

                if (groupName.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Buyer group name cannot be empty.'),
                    ),
                  );
                  return;
                }

                Navigator.of(
                  dialogContext,
                ).pop({'group_name': groupName, 'phone': phone});
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      groupNameController.dispose();
      phoneController.dispose();
    });

    if (result == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _supabase
          .from('buyers')
          .update({
            'group_name': result['group_name'],
            'phone': result['phone'],
          })
          .eq('id', _buyer['id']);

      if (!mounted) return;

      await _refreshBuyer();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buyer information updated successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update buyer: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // DELETE BUYER
  // ============================================================

  Future<void> _deleteBuyer() async {
    final buyerName = _buyer['group_name']?.toString() ?? 'this buyer';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Buyer?'),
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
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
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
        SnackBar(content: Text('Buyer "$buyerName" deleted successfully.')),
      );

      // Return to the Buyers screen because this profile no longer exists.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete buyer: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // PAY DEBT
  // ============================================================

  Future<void> _payDebt() async {
    if (_debt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This buyer has no outstanding debt.')),
      );
      return;
    }

    final controller = TextEditingController();

    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pay Debt'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Payment amount',
              suffixText: 'Birr',
              hintText: 'Current debt: ${_money(_debt)}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());

                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid payment amount.'),
                    ),
                  );
                  return;
                }

                if (value > _debt) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Payment cannot exceed current debt '
                        '(${_money(_debt)}).',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

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

      await _refreshBuyer();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment of ${_money(amount)} recorded successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not record payment: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // ADJUST DEBT
  // ============================================================

  Future<void> _adjustDebt() async {
    final controller = TextEditingController(text: _debt.toStringAsFixed(2));

    final reasonController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Adjust Debt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
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
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Why is the debt being adjusted?',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                final newBalance = double.tryParse(controller.text.trim());

                final reason = reasonController.text.trim();

                if (newBalance == null || newBalance < 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid debt balance.'),
                    ),
                  );
                  return;
                }

                if (reason.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a reason for the adjustment.'),
                    ),
                  );
                  return;
                }

                Navigator.of(
                  dialogContext,
                ).pop({'new_balance': newBalance, 'reason': reason});
              },
              child: const Text('Adjust'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
      reasonController.dispose();
    });

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

      await _refreshBuyer();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buyer debt adjusted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not adjust debt: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isMagala = _buyer['is_magala'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyer Profile'),

        // ========================================================
        // EDIT + DELETE ACTIONS
        // ========================================================
        actions: [
          IconButton(
            tooltip: 'Edit Buyer',
            onPressed: _isLoading ? null : _editBuyer,
            icon: const Icon(Icons.edit_outlined),
          ),

          IconButton(
            tooltip: 'Delete Buyer',
            onPressed: _isLoading ? null : _deleteBuyer,
            icon: const Icon(Icons.delete_outline),
          ),

          const SizedBox(width: 4),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshBuyer,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ==================================================
                  // BUYER HEADER
                  // ==================================================
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            child: Icon(
                              isMagala
                                  ? Icons.storefront_outlined
                                  : Icons.groups_outlined,
                              size: 36,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Text(
                            _buyer['group_name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          if (isMagala)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Chip(label: Text('MAGALA')),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // BUYER INFORMATION
                  // ==================================================
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

                  const SizedBox(height: 16),

                  // ==================================================
                  // CURRENT DEBT
                  // ==================================================
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'Current Debt',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            _money(_debt),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // PAY DEBT
                  // ==================================================
                  if (!isMagala)
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _payDebt,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text(
                          'Pay Debt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // ADJUST DEBT
                  // ==================================================
                  OutlinedButton.icon(
                    onPressed: _adjustDebt,
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Adjust Debt'),
                  ),
                ],
              ),
            ),
    );
  }
}
