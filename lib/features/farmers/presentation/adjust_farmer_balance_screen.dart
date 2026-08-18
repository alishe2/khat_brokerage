import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdjustFarmerBalanceScreen extends StatefulWidget {
  final Map<String, dynamic> farmer;

  const AdjustFarmerBalanceScreen({
    super.key,
    required this.farmer,
  });

  @override
  State<AdjustFarmerBalanceScreen> createState() =>
      _AdjustFarmerBalanceScreenState();
}

class _AdjustFarmerBalanceScreenState
    extends State<AdjustFarmerBalanceScreen> {
  final _supabase = Supabase.instance.client;
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _adjustBalance() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount'),
        ),
      );
      return;
    }

    final reason = _reasonController.text.trim();

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a reason for this adjustment'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _supabase.rpc(
        'adjust_farmer_balance',
        params: {
          'p_farmer_id': widget.farmer['id'],
          'p_amount': amount,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Balance adjusted successfully'),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not adjust balance: $e',
          ),
        ),
      );

      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.farmer['full_name'] ?? 'Farmer';
    final balance = widget.farmer['current_balance'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Balance'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Current balance: $balance Birr',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Positive amount adds money.\n'
              'Negative amount removes money.',
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Adjustment amount',
                hintText: 'Example: 5000 or -500',
                suffixText: 'Birr',
                prefixIcon: Icon(
                  Icons.account_balance_wallet_outlined,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 18),

            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Why is the balance being adjusted?',
                prefixIcon: Icon(
                  Icons.description_outlined,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed:
                    _isSaving ? null : _adjustBalance,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Adjustment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}