import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WithdrawFarmerScreen extends StatefulWidget {
  final Map<String, dynamic> farmer;

  const WithdrawFarmerScreen({
    super.key,
    required this.farmer,
  });

  @override
  State<WithdrawFarmerScreen> createState() =>
      _WithdrawFarmerScreenState();
}

class _WithdrawFarmerScreenState
    extends State<WithdrawFarmerScreen> {
  final _supabase = Supabase.instance.client;

  final _amountController = TextEditingController();
  final _paymentMethodController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _paymentMethodController.dispose();
    super.dispose();
  }

  Future<void> _withdraw() async {
    final amountText = _amountController.text.trim();
    final paymentMethod =
        _paymentMethodController.text.trim();

    final amount = double.tryParse(amountText);

    // ================================================================
    // VALIDATE AMOUNT
    // ================================================================

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid withdrawal amount'),
        ),
      );
      return;
    }

    // ================================================================
    // VALIDATE PAYMENT METHOD
    // ================================================================

    if (paymentMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the payment method'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _supabase.rpc(
        'withdraw_farmer_balance',
        params: {
          'p_farmer_id': widget.farmer['id'],
          'p_amount': amount,
          'p_payment_method': paymentMethod,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal recorded successfully'),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not record withdrawal: $e'),
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
        title: const Text('Withdraw Money'),
      ),
      body: Padding(
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

            const SizedBox(height: 8),

            Text(
              'Available balance: $balance Birr',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 30),

            // ========================================================
            // WITHDRAWAL AMOUNT
            // ========================================================

            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Withdrawal amount',
                suffixText: 'Birr',
                prefixIcon: Icon(
                  Icons.payments_outlined,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 18),

            // ========================================================
            // PAYMENT METHOD
            // ========================================================

            TextField(
              controller: _paymentMethodController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Payment method',
                hintText:
                    'e.g. Cash, Telebirr, CBE Birr, Bank transfer',
                prefixIcon: Icon(
                  Icons.account_balance_wallet_outlined,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // ========================================================
            // CONFIRM
            // ========================================================

            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _withdraw,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm Withdrawal',
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