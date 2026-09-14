import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'seller_profile_screen.dart';

class SellersScreen extends StatefulWidget {
  const SellersScreen({super.key});

  @override
  State<SellersScreen> createState() => _SellersScreenState();
}

class _SellersScreenState extends State<SellersScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _sellers = [];
  List<Map<String, dynamic>> _filteredSellers = [];

  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSellers();

    _searchController.addListener(() {
      _filterSellers(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSellers() async {
    try {
      final data = await _supabase
          .from('sellers')
          .select('id, seller_code, full_name, phone, current_debt, is_active')
          .eq('is_active', true)
          .order('full_name');

      if (!mounted) return;

      setState(() {
        _sellers = List<Map<String, dynamic>>.from(data);
        _filteredSellers = _sellers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load sellers: $e')));
    }
  }

  void _filterSellers(String query) {
    final search = query.trim().toLowerCase();

    setState(() {
      if (search.isEmpty) {
        _filteredSellers = _sellers;
      } else {
        _filteredSellers = _sellers.where((seller) {
          final name = (seller['full_name'] ?? '').toString().toLowerCase();
          final code = (seller['seller_code'] ?? '').toString().toLowerCase();
          final phone = (seller['phone'] ?? '').toString().toLowerCase();

          return name.contains(search) ||
              code.contains(search) ||
              phone.contains(search);
        }).toList();
      }
    });
  }

  Future<void> _showAddSellerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Seller'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
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
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter the seller name')),
                  );
                  return;
                }

                try {
                  final sellerCode =
                      'SEL-${DateTime.now().millisecondsSinceEpoch}';

                  await _supabase.from('sellers').insert({
                    'seller_code': sellerCode,
                    'full_name': name,
                    'phone': phone.isEmpty ? null : phone,
                    'is_active': true,
                  });

                  if (!dialogContext.mounted) return;

                  Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Could not add seller: $e')),
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
      nameController.dispose();
      phoneController.dispose();
    });

    if (result == true && mounted) {
      await _loadSellers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sellers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSellerDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Seller'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSellers,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search sellers...',
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
                    child: _filteredSellers.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 150),
                              Center(child: Text('No sellers found.')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _filteredSellers.length,
                            itemBuilder: (context, index) {
                              final seller = _filteredSellers[index];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person_outline),
                                  ),

                                  title: Text(
                                    seller['full_name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(seller['seller_code'] ?? 'No code'),
                                      Text(
                                        seller['phone'] ?? 'No phone number',
                                      ),
                                      Text(
                                        'Debt: ${((seller['current_debt'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} Birr',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color:
                                              ((seller['current_debt'] as num?)
                                                          ?.toDouble() ??
                                                      0) >
                                                  0
                                              ? Colors.red.shade700
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),

                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                  ),

                                  // Open Seller Profile
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SellerProfileScreen(seller: seller),
                                      ),
                                    );

                                    // Refresh the seller list after returning.
                                    if (mounted) {
                                      await _loadSellers();
                                    }
                                  },
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
