import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const double _kCardRadius = 16;

class SalesByBuyerScreen extends StatefulWidget {
  final String? startDate; // 'yyyy-MM-dd'; null (with endDate null) = all time
  final String? endDate;
  final String title;

  const SalesByBuyerScreen({
    super.key,
    this.startDate,
    this.endDate,
    this.title = 'Sales by Buyer',
  });

  @override
  State<SalesByBuyerScreen> createState() => _SalesByBuyerScreenState();
}

class _SalesByBuyerScreenState extends State<SalesByBuyerScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  double _grandTotal = 0;

  List<Map<String, dynamic>> _buyerTotals = [];

  @override
  void initState() {
    super.initState();
    _loadSalesByBuyer();
  }

  Future<void> _loadSalesByBuyer() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final hasDateFilter = widget.startDate != null && widget.endDate != null;
      final isSingleDate =
          hasDateFilter && widget.startDate == widget.endDate;

      var query = _supabase
          .from('sale_buyers')
          .select(
            'buyer_id, total_amount, sales!inner(sale_date), buyers(group_name, is_magala)',
          );

      if (hasDateFilter) {
        if (isSingleDate) {
          query = query.eq('sales.sale_date', widget.startDate!);
        } else {
          query = query
              .gte('sales.sale_date', widget.startDate!)
              .lte('sales.sale_date', widget.endDate!);
        }
      }

      final data = await query;

      // Group and sum total_amount per buyer_id. Magala needs no
      // special handling — it's a normal buyers row with is_magala
      // = true, so it groups in alongside everyone else.
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final row in data) {
        final buyerId = row['buyer_id']?.toString();
        if (buyerId == null) continue;

        final buyerInfo = row['buyers'] as Map<String, dynamic>?;
        final groupName =
            buyerInfo?['group_name']?.toString() ?? 'Unknown Buyer';
        final isMagala = buyerInfo?['is_magala'] as bool? ?? false;
        final amount = (row['total_amount'] as num?)?.toDouble() ?? 0;

        if (grouped.containsKey(buyerId)) {
          grouped[buyerId]!['total'] =
              (grouped[buyerId]!['total'] as double) + amount;
        } else {
          grouped[buyerId] = {
            'groupName': groupName,
            'isMagala': isMagala,
            'total': amount,
          };
        }
      }

      final buyerTotals = grouped.values.toList()
        ..sort(
          (a, b) => (b['total'] as double).compareTo(a['total'] as double),
        );

      final grandTotal = buyerTotals.fold<double>(
        0,
        (sum, entry) => sum + (entry['total'] as double),
      );

      if (!mounted) return;

      setState(() {
        _buyerTotals = buyerTotals;
        _grandTotal = grandTotal;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load sales: $e')));
    }
  }

  String _money(double amount) {
    return '${amount.toStringAsFixed(2)} Birr';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: _loadSalesByBuyer,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kCardRadius),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.trending_up_rounded,
                          size: 28,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Sales',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isLoading ? '...' : _money(_grandTotal),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'By Buyer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_buyerTotals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No sales recorded for this period.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              else
                ..._buyerTotals.map((entry) {
                  final groupName = entry['groupName'] as String;
                  final isMagala = entry['isMagala'] as bool;
                  final total = entry['total'] as double;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_kCardRadius),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.groups_outlined,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      groupName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (isMagala) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary
                                            .withValues(alpha: 0.10),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Magala',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Text(
                              _money(total),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}