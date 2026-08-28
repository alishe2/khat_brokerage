import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkerFeesScreen extends StatefulWidget {
  const WorkerFeesScreen({super.key});

  @override
  State<WorkerFeesScreen> createState() => _WorkerFeesScreenState();
}

class _WorkerFeesScreenState extends State<WorkerFeesScreen> {
  final _supabase = Supabase.instance.client;

  final _amountController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  double _todayAmount = 0;

  String get _today {
    final now = DateTime.now();

    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadTodayFee();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayFee() async {
    try {
      final data = await _supabase
          .from('worker_fees')
          .select('amount')
          .eq('fee_date', _today)
          .maybeSingle();

      if (!mounted) return;

      final amount =
          (data?['amount'] as num?)?.toDouble() ?? 0;

      setState(() {
        _todayAmount = amount;

        _amountController.text =
            amount == 0 ? '' : amount.toStringAsFixed(2);

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load worker fees: $e',
          ),
        ),
      );
    }
  }

  Future<void> _saveFee() async {
    final text = _amountController.text.trim();

    final amount = double.tryParse(text);

    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid worker fee amount',
          ),
        ),
      );

      return;
    }

    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not logged in'),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Check whether today's record already exists.
      final existing = await _supabase
          .from('worker_fees')
          .select('id')
          .eq('fee_date', _today)
          .maybeSingle();

      if (existing != null) {
        // Update today's existing total.
        await _supabase
            .from('worker_fees')
            .update({
              'amount': amount,
            })
            .eq('id', existing['id']);
      } else {
        // Create today's fee record.
        await _supabase
            .from('worker_fees')
            .insert({
              'fee_date': _today,
              'amount': amount,
              'recorded_by': userId,
            });
      }

      if (!mounted) return;

      setState(() {
        _todayAmount = amount;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Worker fees saved successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save worker fees: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Fees'),
      ),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadTodayFee,

              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 60,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Today\'s Worker Fees',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _today,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Worker Fees',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextField(
                            controller: _amountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              hintText:
                                  'Enter total worker fees',
                              suffixText: 'Birr',
                              prefixIcon: Icon(
                                Icons.payments_outlined,
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed:
                                  _isSaving ? null : _saveFee,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.save_outlined,
                                    ),
                              label: Text(
                                _isSaving
                                    ? 'Saving...'
                                    : 'Save Worker Fees',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'Today\'s Recorded Amount',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            '${_todayAmount.toStringAsFixed(2)} Birr',
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

                  Text(
                    'You can change the amount during the day. '
                    'Saving again updates today\'s total worker fees.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}