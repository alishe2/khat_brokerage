import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:khat_brokerage/features/worker_fees/presentation/worker_fees_screen.dart';

class OtherExpensesScreen extends StatefulWidget {
  const OtherExpensesScreen({super.key});

  @override
  State<OtherExpensesScreen> createState() => _OtherExpensesScreenState();
}

class _OtherExpensesScreenState extends State<OtherExpensesScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;

  List<Map<String, dynamic>> _expenses = [];

  double get _totalToday {
    double total = 0;

    for (final expense in _expenses) {
      total += (expense['amount'] as num?)?.toDouble() ?? 0;
    }

    return total;
  }

  String get _today {
    final now = DateTime.now();

    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final data = await _supabase
          .from('other_expenses')
          .select('id, amount, description, expense_date, created_at')
          .eq('expense_date', _today)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _expenses = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load other expenses: $e')),
      );
    }
  }

  Future<void> _addExpense() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddExpenseDialog(),
    );

    if (result == true && mounted) {
      await _loadExpenses();
    }
  }

  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    final description = expense['description']?.toString() ?? 'expense';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Expense'),
          content: Text('Are you sure you want to delete "$description"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('other_expenses').delete().eq('id', expense['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted successfully')),
      );

      await _loadExpenses();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete expense: $e')));
    }
  }

  String _money(double amount) {
    return '${amount.toStringAsFixed(2)} Birr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Other Expense'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadExpenses,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // ======================================================
                  // WORKER FEES
                  // ======================================================
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.people_outline),
                      ),
                      title: const Text(
                        'Worker Fees',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Manage today\'s worker fees'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WorkerFeesScreen(),
                          ),
                        );

                        if (mounted) {
                          await _loadExpenses();
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ======================================================
                  // TODAY'S OTHER EXPENSES SUMMARY
                  // ======================================================
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 42),
                          const SizedBox(height: 12),
                          const Text(
                            'Today\'s Other Expenses',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _today,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _money(_totalToday),
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

                  // ======================================================
                  // OTHER EXPENSES LIST
                  // ======================================================
                  const Text(
                    'Recorded Other Expenses',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  if (_expenses.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No other expenses recorded today',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap "Other Expense" to add one.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._expenses.map(
                      (expense) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.payments_outlined),
                          ),
                          title: Text(
                            expense['description']?.toString() ?? 'Expense',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            expense['expense_date']?.toString() ?? _today,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _money(
                                  (expense['amount'] as num?)?.toDouble() ?? 0,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: () {
                                  _deleteExpense(expense);
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }
}

// ======================================================================
// ADD EXPENSE DIALOG
// ======================================================================

class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog();

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _supabase = Supabase.instance.client;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());

    final description = _descriptionController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid expense amount')),
      );
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a description')));
      return;
    }

    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You are not logged in')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _supabase.from('other_expenses').insert({
        'expense_date': DateTime.now().toIso8601String().substring(0, 10),
        'amount': amount,
        'description': description,
        'recorded_by': userId,
      });

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save expense: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Other Expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Food, water, transport...',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                suffixText: 'Birr',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
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
