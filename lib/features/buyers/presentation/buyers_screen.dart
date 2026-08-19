import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BuyersScreen extends StatefulWidget {
  const BuyersScreen({super.key});

  @override
  State<BuyersScreen> createState() => _BuyersScreenState();
}

class _BuyersScreenState extends State<BuyersScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _buyers = [];
  List<Map<String, dynamic>> _filteredBuyers = [];

  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBuyers();

    _searchController.addListener(() {
      _filterBuyers(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBuyers() async {
    try {
      final data = await _supabase
          .from('buyers')
          .select('id, buyer_code, group_name, phone, current_debt, is_magala')
          .eq('is_active', true)
          .order('group_name');

      if (!mounted) return;

      setState(() {
        _buyers = List<Map<String, dynamic>>.from(data);
        _filteredBuyers = _buyers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load buyers: $e')));
    }
  }

  void _filterBuyers(String query) {
    final search = query.trim().toLowerCase();

    setState(() {
      if (search.isEmpty) {
        _filteredBuyers = _buyers;
      } else {
        _filteredBuyers = _buyers.where((buyer) {
          final group = (buyer['group_name'] ?? '').toString().toLowerCase();
          final code = (buyer['buyer_code'] ?? '').toString().toLowerCase();
          final phone = (buyer['phone'] ?? '').toString().toLowerCase();

          return group.contains(search) ||
              code.contains(search) ||
              phone.contains(search);
        }).toList();
      }
    });
  }

  Future<void> _showAddBuyerDialog() async {
    final groupController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Buyer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: groupController,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
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
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final groupName = groupController.text.trim();
                final phone = phoneController.text.trim();

                if (groupName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter the buyer group name')),
                  );
                  return;
                }

                try {
                  final buyerCode =
                      'BUY-${DateTime.now().millisecondsSinceEpoch}';

                  await _supabase.from('buyers').insert({
                    'buyer_code': buyerCode,
                    'group_name': groupName,
                    'phone': phone.isEmpty ? null : phone,
                    'current_debt': 0,
                    'is_magala': false,
                    'is_active': true,
                  });

                  if (!dialogContext.mounted) return;

                  Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not add buyer: $e')),
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

    if (result == true && mounted) {
      await _loadBuyers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buyers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBuyerDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Buyer'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBuyers,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search buyers...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _searchController.clear,
                                icon: const Icon(Icons.clear),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: _filteredBuyers.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 150),
                              Center(child: Text('No buyers found.')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _filteredBuyers.length,
                            itemBuilder: (context, index) {
                              final buyer = _filteredBuyers[index];

                              final debt = buyer['current_debt'] ?? 0;

                              final isMagala = buyer['is_magala'] == true;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Icon(
                                      isMagala
                                          ? Icons.storefront_outlined
                                          : Icons.groups_outlined,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          buyer['group_name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (isMagala)
                                        const Chip(label: Text('MAGALA')),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(buyer['buyer_code'] ?? 'No code'),
                                      Text(buyer['phone'] ?? 'No phone number'),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Debt',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        '$debt Birr',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
